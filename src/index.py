#!/usr/bin/env python3

import os
import sys
import traceback

import gi
gi.require_version('Gst', '1.0')
gi.require_version('GLib', '2.0')
gi.require_version('GObject', '2.0')
from gi.repository import GLib, GObject, Gst

import logging
logger = logging.getLogger(__name__)
logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)

STREAM_NAME = os.environ.get('STREAM_NAME')
IOT_CREDENTIAL_ENDPOINT = os.environ.get('IOT_CREDENTIAL_ENDPOINT')
CERT_ID = os.environ.get('CERT_ID')

KVS_CMD = f'kvssink stream-name={STREAM_NAME} framerate=15'\
          ' aws-region=ap-northeast-1'\
          ' iot-certificate="iot-certificate,'\
          f'endpoint={IOT_CREDENTIAL_ENDPOINT},'\
          f'cert-path=/greengrass/certs/{CERT_ID}.cert.pem,'\
          f'key-path=/greengrass/certs/{CERT_ID}.private.key,'\
          'ca-path=/greengrass/certs/root.ca.pem,'\
          'role-aliases=KvsCameraIoTRoleAlias"'

DEFAULT_PIPELINE = 'videotestsrc ! clockoverlay auto-resize=false'\
                   ' ! videorate ! video/x-raw,format=I420,framerate=15/1'\
                   ' ! x264enc tune=zerolatency ! h264parse'

def on_message(bus: Gst.Bus, message: Gst.Message, loop: GLib.MainLoop):
    mtype = message.type
    if mtype == Gst.MessageType.EOS:
        logger.info("End of stream")
        loop.quit()

    elif mtype == Gst.MessageType.ERROR:
        err, debug = message.parse_error()
        logger.error(err, debug)
        loop.quit()

    elif mtype == Gst.MessageType.WARNING:
        err, debug = message.parse_warning()
        logger.warning(err, debug)

    return True

def main():
    logger.info('Start gstream pipeline')

    Gst.init(sys.argv)

    cmd = os.environ.get('PIPELINE', DEFAULT_PIPELINE)
    if os.environ.get('USE_KVS', True):
        cmd += f' ! {KVS_CMD}'
    logger.info('Pipeline : %s', cmd)

    pipeline = Gst.parse_launch(cmd)
    bus = pipeline.get_bus()
    bus.add_signal_watch()
    pipeline.set_state(Gst.State.PLAYING)
    loop = GLib.MainLoop()
    bus.connect("message", on_message, loop)

    try:
        loop.run()
    except Exception:
        traceback.print_exc()
        loop.quit()

    pipeline.set_state(Gst.State.NULL)

main()

# This is a dummy handler and will not be invoked
# Instead the code above will be executed in an infinite loop for our example
def function_handler(event, context):
    return
