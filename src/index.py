#!/usr/bin/env python3

import sys
import random

import gi
gi.require_version('Gst', '1.0')
gi.require_version('GLib', '2.0')
gi.require_version('GObject', '2.0')
from gi.repository import GLib, GObject, Gst

import logging
logger = logging.getLogger(__name__)
logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)

class ProbeData:
    def __init__(self, pipe, src):
        self.pipe = pipe
        self.src = src

def bus_call(bus, message, loop):
    t = message.type
    if t == Gst.MessageType.EOS:
        sys.stdout.write("End-of-stream\n")
        loop.quit()
    elif t == Gst.MessageType.ERROR:
        err, debug = message.parse_error()
        sys.stderr.write("Error: %s: %s\n" % (err, debug))
        loop.quit()
    return True

def main():
    logger.info('Start gstream pipeline')

    Gst.init(None)

    pipe = Gst.Pipeline.new('dynamic')
    src = Gst.ElementFactory.make('videotestsrc')
    sink = Gst.ElementFactory.make('mysink')
    pipe.add(src, sink)
    src.link(sink)

    loop = GObject.MainLoop()

    bus = pipe.get_bus()
    bus.add_signal_watch()
    bus.connect ("message", bus_call, loop)

    pipe.set_state(Gst.State.PLAYING)
    try:
        loop.run()
    except Exception as e:
        logger.error(e)
    pipe.set_state(Gst.State.NULL)

main()

# This is a dummy handler and will not be invoked
# Instead the code above will be executed in an infinite loop for our example
def function_handler(event, context):
    return

