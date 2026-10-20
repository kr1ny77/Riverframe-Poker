#!/usr/bin/env python3
"""Validate actual network-denial probes from the dedicated Simulator QA app."""
import json
from pathlib import Path
import shutil
import socket
import subprocess
import sys

if len(sys.argv) != 4:
    raise SystemExit('usage: collect-offline-proof.py QA_DEVICE OUTPUT SINCE_UNIX_SECONDS')
device, destination, since_text = sys.argv[1:]
since = float(since_text)
listing = json.loads(subprocess.check_output(['xcrun','simctl','list','devices','-j']))
matches = [d for group in listing['devices'].values() for d in group if d['udid'] == device]
assert len(matches) == 1 and matches[0]['name'].startswith('Poker QA'), 'Dedicated QA simulator required'
container = Path(subprocess.check_output(['xcrun','simctl','get_app_container',device,'org.pokerpractice.native','data'],text=True).strip())
out = Path(destination)
out.mkdir(parents=True,exist_ok=True)
files = sorted(p for p in (container/'tmp').glob('qa-network-*.json') if p.stat().st_mtime >= since)
proofs = []
for file in files:
    shutil.copy2(file,out/file.name)
    proof = json.loads(file.read_text())
    proofs.append(proof)
    assert proof['sandbox_result'] == 0, proof
    assert proof['profile'] == 'qa-deny-ip' and proof['profile_bytes'] > 0, proof
    assert proof['external_connect_errno'] in [1,13], proof
    assert proof['loopback_connect_errno'] in [1,13], proof
    assert proof['case'] == 'testOfflineAllSections', proof
assert len(proofs) >= 5, f'Expected at least five isolated application launches, got {len(proofs)}'
assert len({p['process'] for p in proofs}) == len(proofs), 'Distinct launch processes required'
controls = {}
for host in ['1.1.1.1','example.com']:
    try:
        with socket.create_connection((host,443),timeout=4):
            controls[host] = 'host TCP443 connected'
    except OSError as error:
        controls[host] = repr(error)
summary = {'launches':len(proofs),'processes':[p['process'] for p in proofs],
           'result':'PASS: application process has no IP network; all UI flows completed',
           'external_errno':[p['external_connect_errno'] for p in proofs],
           'loopback_errno':[p['loopback_connect_errno'] for p in proofs],
           'host_network_controls':controls}
(out/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(summary,ensure_ascii=False,indent=2))
