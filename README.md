# gg_gst

```
$ docker build -t gg_gst .
$ xhost +local:
$ docker run -it -e DISPLAY=$DISPLAY -v /tmp/.X11-unix/:/tmp/.X11-unix gg_gst
```
