import os
import logging
import greengrasssdk
import json
import traceback

import gi
gi.require_version('GstBase', '1.0')
gi.require_version('Gst', '1.0')
gi.require_version('GLib', '2.0')
gi.require_version('GObject', '2.0')

from gi.repository import GstBase, Gst, GLib, GObject
from gstreamer.gst_objects_info_meta import gst_meta_get

class AwsIotNotify(GstBase.BaseTransform):
    __gstmetadata__ = ('AWS IoT Notify',
                       'Transform',
                       'AWS IoT Notify plugin',
                       'sabmeua<sabme.ua@gmail.com>')

    __gsttemplates__ = (Gst.PadTemplate.new('src',
                                            Gst.PadDirection.SRC,
                                            Gst.PadPresence.ALWAYS,
                                            Gst.Caps.from_string('video/x-raw,format=RGB')),
                        Gst.PadTemplate.new('sink',
                                            Gst.PadDirection.SINK,
                                            Gst.PadPresence.ALWAYS,
                                            Gst.Caps.from_string('video/x-raw,format=RGB')))

    def __init__(self):
        super().__init__()
        self.detection = False
        self.client = greengrasssdk.client('iot-data')

    def do_transform_ip(self, buffer: Gst.Buffer) -> Gst.FlowReturn:
        try:
            objects = gst_meta_get(buffer)
            pts = Gst.TIME_ARGS(buffer.pts)

            prev, self.detection = self.detection, False
            if objects:
                self.detection = True
                if not prev:
                    detection = objects[0]
                    detection['pts'] = pts
                    self.client.publish(topic='object/detection', qos=0, payload=detection)

        except Exception as err:
            Gst.error(f"Error {self}: {traceback.format_exc()}")

        return Gst.FlowReturn.OK


GObject.type_register(AwsIotNotify)
__gstelementfactory__ = ('awsiot_notify', Gst.Rank.NONE, AwsIotNotify)
