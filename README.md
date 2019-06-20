resty-imaging
=============

Micro-service approach to resizing, cropping, rounding and serving images. 
Built with openresty, lua and C++.

Provides a simple to deploy backend for common image operations for mobile
applications, including resizing images for different device sizes and making
round images for avatars. 


License
-------

MIT-license. I built this mainly to learn libvips and lua. Hopefully it benefits others.


How to use it?
--------------

The easiest way to get started is to open the docker-compose.yml and edit
IMAGING_ALLOWED_ORIGINS to space separated list of domains where you want
to load images from. After that the usual:

```
docker-compose build
docker-compose run
```

The default configuration listens to 8080 and 8081 ports. The former has a 
cache configured in the nginx conf and the latter is direct access to the 
image processing engine.

nginx.conf can be modified to suit your needs (change urls, cache sizes etc).

The following environment variables can be used to tune defaults:

```
IMAGING_ALLOWED_ORIGINS - Space separated list of allowed upstream domains
IMAGING_MAX_WIDTH       - Maximum width of output image
IMAGING_MAX_HEIGHT      - Maximum height of output image
IMAGING_MAX_OPERATIONS  - Maximum amount of operations in one call
IMAGING_DEFAULT_QUALITY - Default quality of JPEG output images
IMAGING_DEFAULT_STRIP   - Whether to strip output images
IMAGING_DEFAULT_FORMAT  - Default output format if none specified
IMAGING_MAX_CONCURRENCY - The maximum concurrency of libvips
IMAGING_NAMED_OPERATIONS_FILE - Path to a file that contains list of predefined operations
```

The format for IMAGING_NAMED_OPERATIONS_FILE is the following:

```
thumbnail: resize/w=500,h=500,m=fit/crop/w=200,h=200,g=sw/format/t=webp
avatar: resize/w=100,h=100,m=crop/round/p=100/format/t=jpg
```



URLs
----

The urls in resty-imaging work in the following way:

```
http://localhost:8080/<operation name>/<operation params>/<operation name>/<operation params>/.../http://another.example.com/original.jpg
```

The three dots above mean that you can keep on putting operations and params as needed.
They are actually not required or allowed in the url. Imagine, I had to add this note
separately because a friend of mine sent a message saying "Hey, it looks good but I am getting
an error with the dots".

Currently resty-imaging recognises the following operation names:

* resize, make images smaller or larger

Allowed params:

```
w (integer) - width 
h (integer) - height
m (string)  - mode. Allowed modes are: fit, fill and crop
```

* crop, chop a piece of the image

```
w (integer) - width
h (integer) - height
g (string)  - gravity, i.e. which part of the image to crop.

Here are the constants for gravity values:

n      = GravityNorth
ne     = GravityNorthEast
e      = GravityEast
se     = GravitySouthEast
s      = GravitySouth
sw     = GravitySouthWest
w      = GravityWest
nw     = GravityNorthWest
center = GravityCenter
smart  = GravitySmart
```

The smart crop works along the lines of seam carving (try to crop areas that are less relevant).


* round, make circle images. Think avatars

```
p (integer) - amount as percentage to round the image
x (integer) - radius x (optional, cryptic)
y (integer) - radius y (optional, cryptic)

```

* format, switch image formats. Format counts only once so specifying it multiple times between operations is pointless.

```
t (string) - what format to use. Supported format depends on what libvips is configured with
q (integer) - output quality (between 1 and 100) for jpeg images
s (boolean) - strip output
```

* named, use a predefined operation from IMAGING_NAMED_OPERATIONS_FILE

```
n (string) - the name of the operation
```

* blur, gaussian blur operation

```
s (double) - the sigma value for gaussian blur
```

Some examples
-------------

```
http://localhost:8080/resize/w=500,h=500,m=crop/http://another.example.com/original.jpg
```

```
http://localhost:8080/resize/w=500,h=500,m=fit/crop/w=200,h=200,g=center/format/t=png/http://another.example.com/original.jpg
```

Tests
-----

Run the following commands:

```
$ docker-compose up
$ ./test.sh
```

Credits
-------

Thanks to https://github.com/lovell/sharp for having open source code based on libvips available,
some of the routines in the C++ library are based on the code in this library as libvips wasn't
the most accessible at first go.

Other parts are based on libvips manual and random code samples.







