import argparse
import logging
import os
import socket
import subprocess
import sys
import time
import uuid

from contextlib import closing
from pathlib import Path
from threading import Thread
from scapy.all import *

def get_packet_hash(packet):
    if packet.haslayer(TCP):
        # Extract TCP packet fields that uniquely identify it
        tcp_layer = packet[TCP]

        # Create a string combining fields that should be unique per packet
        unique_data = f"{tcp_layer.sport}{tcp_layer.dport}{tcp_layer.seq}{tcp_layer.ack}{tcp_layer.flags}"

        # If the packet has a payload, include it as well
        if packet.haslayer(Raw):
            unique_data += str(packet[Raw].load)

        # Compute the checksum (or hash) of the unique data
        return hashlib.sha256(unique_data.encode()).hexdigest()
    return None

def unique_tcp_packets(packets_a, packets_b):
    packets = packets_a
    packet_hashes = [get_packet_hash(p) for p in packets]
    for packet in packets_b:
        if packet.haslayer(TCP):
            packet_hash = get_packet_hash(packet)
            if not packet_hash in packet_hashes:
                packet_hashes.append(packet_hash)
                continue
        packets.append(packet)
    packets.sort(key=lambda pkt: pkt.time)
    return packets

class PolarProxySniffer(Thread):
    def __init__(self, log, polar_path, pcap_path, cert, password, listen_port=0, inetsim=""):
        super().__init__()
        self.log = log
        self.daemon = True
        self.pid = None
        self.polar_path = polar_path
        self.pcap_path = pcap_path
        self.cert = cert
        self.password = password
        self.listen_port = listen_port or self.find_free_port()
        self.inetsim = inetsim
        self.base_cmd = f"{self.polar_path} -v -w {self.pcap_path} --writeall --autoflush 1 --cacert load:{self.cert}:{self.password}"

        if inetsim:
            self.polar_cmd = f"{self.base_cmd} -p {self.listen_port},443,80 --terminate --nosni nosni.inetsim.org --leafcert sign --connect {self.inetsim}"
        else:
            self.polar_cmd = f"{self.base_cmd} -p {self.listen_port},80,443"

    def find_free_port(self):
        with closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as s:
            s.bind(('', 0))
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            return s.getsockname()[1]

    def run(self):
        self.log.info("Starting PolarProxy process")

        old_pids = self.get_process_id()

        self.log.info("PolarProxy Command: %s", self.polar_cmd)
        os.system(f"{self.polar_cmd} 2>&1 &")

        new_pids = [
            new_pid for new_pid in self.get_process_id() if new_pid not in old_pids
        ]
        if len(new_pids) > 1 or len(new_pids) == 0:
            self.pid = None
            raise ValueError(
                f"Unable to get PID of PolarProxy (old pids:{old_pids}, new pids:{new_pids})"
            )

        self.log.debug("Old PolarProxy PIDs: %s", old_pids)
        self.log.debug("New PolarProxy PIDs: %s", new_pids)

        self.pid = new_pids[0]
        self.log.info("Started proxy with PID %d", self.pid)

    @classmethod
    def get_process_id(cls):
        child = subprocess.Popen(
            ["pgrep", "PolarProxy"], stdout=subprocess.PIPE, shell=False
        )
        response = child.communicate()[0]
        return [int(pid) for pid in response.split()]

    def join(self, timeout=None):
        self.log.info("Killing proxy with PID %d", self.pid)
        proc = subprocess.Popen(
            ["kill", str(self.pid)], stdout=subprocess.PIPE, stderr=subprocess.PIPE
        )
        proc.wait()
        super().join(timeout)
        self.returncode = proc.returncode

    def is_running(self):
        if not self.pid:
            return False
        else:
            proc = subprocess.Popen(
                ["ps", str(self.pid)], stdout=subprocess.PIPE, stderr=subprocess.PIPE
            )
            proc.wait()
            return proc.returncode == 0

    @classmethod
    def kill_all(cls):
        pids = cls.get_process_id()
        for pid in pids:
            self.log.info("Force killing PID %d", pid)
            proc = subprocess.Popen(
                ["kill", "-9", str(pid)], stdout=subprocess.PIPE, stderr=subprocess.PIPE
            )
            proc.wait()

