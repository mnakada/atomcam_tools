#!/usr/bin/env python3
# Receive a go2rtc WebRTC stream for some seconds and print what arrived (needs aiortc).
# go2rtc の WebRTC を数秒受け取り、届いた映像と音声を表示する（aiortc が必要）
#
# usage: webrtc_recv.py URL SECONDS
#   URL : go2rtc WebRTC API, e.g. http://atomcam.local:1984/api/webrtc?src=video0
# output: video <frames> <width>x<height> audio <frames> <rate>
# Exit status: 0 if video frames arrived, 1 otherwise.

import asyncio
import json
import sys
import urllib.request

from aiortc import RTCPeerConnection, RTCSessionDescription


async def receive(url, seconds):
    pc = RTCPeerConnection()
    pc.addTransceiver('video', direction='recvonly')
    pc.addTransceiver('audio', direction='recvonly')
    got = {'video': 0, 'audio': 0, 'size': '-', 'rate': '-'}
    tasks = []

    async def count(track):
        while True:
            frame = await track.recv()
            got[track.kind] += 1
            if track.kind == 'video':
                got['size'] = f'{frame.width}x{frame.height}'
            else:
                got['rate'] = str(frame.sample_rate)

    @pc.on('track')
    def on_track(track):
        tasks.append(asyncio.ensure_future(count(track)))

    await pc.setLocalDescription(await pc.createOffer())
    req = urllib.request.Request(url, method='POST', headers={'Content-Type': 'application/json'},
                                 data=json.dumps({'type': 'offer', 'sdp': pc.localDescription.sdp}).encode())
    answer = json.loads(await asyncio.get_running_loop().run_in_executor(
        None, lambda: urllib.request.urlopen(req, timeout=10).read()))
    await pc.setRemoteDescription(RTCSessionDescription(sdp=answer['sdp'], type=answer['type']))
    await asyncio.sleep(seconds)
    for t in tasks:
        t.cancel()
    await pc.close()
    return got


def main():
    if len(sys.argv) != 3:
        print(f'usage: {sys.argv[0]} URL SECONDS', file=sys.stderr)
        return 2
    try:
        got = asyncio.run(receive(sys.argv[1], float(sys.argv[2])))
    except Exception as e:
        print(f'error: {e}')
        return 1
    print(f"video {got['video']} {got['size']} audio {got['audio']} {got['rate']}")
    return 0 if got['video'] > 0 else 1


if __name__ == '__main__':
    sys.exit(main())
