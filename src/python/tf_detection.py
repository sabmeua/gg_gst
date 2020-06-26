import os
import logging
import numpy as np
import tensorflow as tf

import gi
gi.require_version('GstBase', '1.0')
gi.require_version('Gst', '1.0')
gi.require_version('GLib', '2.0')
gi.require_version('GObject', '2.0')

from gi.repository import GstBase, Gst, GLib, GObject
Gst.init(None)

class GstTensorflowDetection(GstBase.BaseTransform):
    __gstmetadata__ = ('Identity Python',
                       'Transform',
                       'Tensorflow object detection plugin',
                       'sabmeua<sabme.ua@gmail.com>')

    __gsttemplates__ = (Gst.PadTemplate.new('src',
                                           Gst.PadDirection.SRC,
                                           Gst.PadPresence.ALWAYS,
                                           Gst.Caps.from_string('video/x-raw,format=RGB')),
                        Gst.PadTemplate.new('sink',
                                           Gst.PadDirection.SINK,
                                           Gst.PadPresence.ALWAYS,
                                           Gst.Caps.from_string('video/x-raw,format=RGB')))
    __gproperties__ = {
        'config': (str,
                   'Path to config yml',
                   'Contains path to Tensorflow configuration file',
                   None,
                   GObject.ParamFlags.READWRITE)}

    def do_transform_ip(self, buffer):
        Gst.info("timestamp(buffer):%s" % (Gst.TIME_ARGS(buffer.pts)))
        return Gst.FlowReturn.OK

GObject.type_register(GstTensorflowDetection)
__gstelementfactory__ = ('tf_detection', Gst.Rank.NONE, GstTensorflowDetection)

