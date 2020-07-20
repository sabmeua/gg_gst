import os
import logging
import numpy as np
import tensorflow.compat.v1 as tf
import gstreamer.utils as utils
import cv2
import json
import traceback

import gi
gi.require_version('GstBase', '1.0')
gi.require_version('Gst', '1.0')
gi.require_version('GLib', '2.0')
gi.require_version('GObject', '2.0')

from gi.repository import GstBase, Gst, GLib, GObject
from gstreamer.gst_objects_info_meta import gst_meta_write

Gst.init(None)

PROC_WIDTH = 300
PROC_HEIGHT = 300
PROC_INTERPOLATION = cv2.INTER_NEAREST

PERSON = 1
THRESHOLD = 0.9

class GstObjectDetection(GstBase.BaseTransform):
    __gstmetadata__ = ('Object Detection',
                       'Transform',
                       'Object Detection plugin',
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
        "model": (str,
                  "Path to model pb file",
                  "Path to model pb file",
                  None,
                  GObject.ParamFlags.READWRITE)
    }

    def do_get_property(self, prop: GObject.GParamSpec):
        if prop.name != 'model':
            raise AttributeError('Unknown property %s' % prop.name)

        return self.model

    def do_set_property(self, prop: GObject.GParamSpec, value):
        logging.debug('do_set_property')
        if prop.name != 'model':
            raise AttributeError('Unknown property %s' % prop.name)

        self.model = value
        model_dir = os.environ.get('AWS_GG_RESOURCE_PREFIX', '/models')
        model_path = f'{model_dir}/{self.model}'

        # Prepare graph
        graph = tf.Graph()
        with graph.as_default():
            graph_def = tf.GraphDef()
            with tf.io.gfile.GFile(model_path, 'rb') as f:
                graph_def.ParseFromString(f.read())
                tf.import_graph_def(graph_def, name='')

        # Prepare in/out tensors
        self.output_tensors = {
            'labels': graph.get_tensor_by_name('detection_classes:0'),
            'scores': graph.get_tensor_by_name('detection_scores:0')
        }
        self.input_tensors = {
            'images': graph.get_tensor_by_name('image_tensor:0')
        }
        self.session = tf.Session(graph=graph)

    def __init__(self):
        super().__init__()
        self.session = None
        self.input_tensors = None
        self.output_tensors = None
        self.model = None
        logging.debug('init')

    def resize(self, image: np.ndarray) -> np.ndarray:
        return cv2.resize(image, (PROC_WIDTH, PROC_HEIGHT), PROC_INTERPOLATION)

    def process(self, image: np.ndarray):
        image = self.resize(image)
        image = np.expand_dims(image, axis=0)
        # Run inference
        result = self.session.run(self.output_tensors,
                                  feed_dict={self.input_tensors['images']: image})

        # Select results
        detections = []
        for labels, scores in zip(result['labels'], result['scores']):
            persons = filter(lambda d: d[0] == PERSON and d[1] > THRESHOLD, zip(labels, scores))
            for _, score in persons:
                logging.debug(f'Detect score={score}')
                detections.append({
                    'class_name': 'person',
                    'confidence': float(score),
                    'bounding_box': [0, 0, 0, 0], # dummy
                })
        return detections

    def do_transform_ip(self, buffer: Gst.Buffer):
        try:
            caps = self.sinkpad.get_current_caps()
            image = utils.gst_buffer_with_caps_to_ndarray(buffer, caps)
            detections = self.process(image)
            gst_meta_write(buffer, detections)

        except Exception as err:
            Gst.error(f'Error {self}: {traceback.format_exc()}')

        return Gst.FlowReturn.OK


GObject.type_register(GstObjectDetection)
__gstelementfactory__ = ('object_detection', Gst.Rank.NONE, GstObjectDetection)
