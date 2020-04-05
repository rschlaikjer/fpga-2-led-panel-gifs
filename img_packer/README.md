# Image packer

Given a series if input images that are 64x64 pixels, generates a packed image
file of RGB565 encoded frames that can then be displayed by the rendering
gateware.

## Building

Ensure you have CMake and a C compiler installed, and then

    mkdir build
    cd build
    cmake ../
    make

## Running

First, convert your input image into 64x64 pixel frames

    # Resize the gif to 64x64 pixels, ignoring aspect ratio
    convert -resize 64x64\! nyan_fullres.gif nyan_64.gif
    # Convert the resized gif into individual frames
    # This will generate nyan_frame-0.png through nyan_frame-11.png
    convert -coalesce nyan_64.gif nyan_frame.png

Now that you have a series of images, you can pack them into a file called
`nyancat.bin` using the invocation

    img_pack nyancat.bin nyan_frame-{0..11}.png

