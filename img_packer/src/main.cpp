#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <arpa/inet.h>

#define STB_IMAGE_IMPLEMENTATION
#include <stb_image.h>

#include <memory>

static const int IMAGE_EDGE_PX = 64;
static const int PIXEL_DEPTH_BYTES = 2;
static const int PACKED_FRAME_SIZE_BYTES =
    IMAGE_EDGE_PX * IMAGE_EDGE_PX * PIXEL_DEPTH_BYTES;

using ManagedPointer = std::unique_ptr<unsigned char[], decltype(std::free) *>;

ManagedPointer load_image(const char *path, int *w, int *h, int *channels) {
  unsigned char *image_data = stbi_load(path, w, h, channels, 3);
  return ManagedPointer(image_data, std::free);
}

ManagedPointer pack_image_565(unsigned char *rgb_data, int channels) {
  uint16_t *data = static_cast<uint16_t *>(
      calloc(IMAGE_EDGE_PX * IMAGE_EDGE_PX * PIXEL_DEPTH_BYTES, 1));
  // To get as much data in there as we can, just pack it as RGB 565
  for (int i = 0; i < IMAGE_EDGE_PX * IMAGE_EDGE_PX; i++) {
    uint8_t r, g, b;
    // Handle possibility of alpha
    if (channels == 4) {
      // RGBA data
      // Just scale the RGB channels by the alpha channel (as though it were
      // alpha over a black background)
      uint8_t a = rgb_data[i * 4 + 2];
      const float alpha_scale = ((float)a) / 255.0;
      r = ((float)rgb_data[i * 4]) * alpha_scale;
      g = ((float)rgb_data[i * 4 + 1]) * alpha_scale;
      b = ((float)rgb_data[i * 4 + 2]) * alpha_scale;
    } else {
      // Straight up RGB
      r = rgb_data[i * 3];
      g = rgb_data[i * 3 + 1];
      b = rgb_data[i * 3 + 2];
    }

    // Pack it into the output data
    data[i] = htons((((r >> 3) & 0b11111) << 11) |
                    (((g >> 2) & 0b111111) << 5) | (((b >> 3) & 0b11111) << 0));
  }

  return ManagedPointer(reinterpret_cast<unsigned char *>(data), std::free);
}

int main(int argc, char **argv) {
  if (argc < 3) {
    fprintf(stderr, "%s output_file input_image_1 [input_image_2,...]\n",
            argv[0]);
    return EXIT_FAILURE;
  }

  // Create/open output file
  int output_fd = ::open(argv[1], O_WRONLY | O_CREAT, 0644);
  if (output_fd == -1) {
    fprintf(stderr, "Failed to open '%s' for writing: %d: %s\n", argv[1], errno,
            strerror(errno));
    return EXIT_FAILURE;
  }

  // Close the file when done
  std::shared_ptr<void> _defer_close_fd(nullptr, [=](...) {
    int ret = close(output_fd);
    if (ret == -1) {
      fprintf(stderr, "Error closing output fd: %d: %s\n", errno,
              strerror(errno));
    }
  });

  for (int img_idx = 2; img_idx < argc; img_idx++) {
    // Load the image
    int width, height, channels;
    ManagedPointer img = load_image(argv[img_idx], &width, &height, &channels);

    // Don't bother with images that are the wrong dimension
    if (width != IMAGE_EDGE_PX || height != IMAGE_EDGE_PX) {
      fprintf(stderr, "Error: File '%s' is %dx%d, not %dx%d\n", argv[img_idx],
              width, height, IMAGE_EDGE_PX, IMAGE_EDGE_PX);
      return EXIT_FAILURE;
    }

    fprintf(stderr, "%s: %d channels\n", argv[img_idx], channels);

    // Pack it to an animation frame
    ManagedPointer packed = pack_image_565(img.get(), channels);

    // Write those bytes to the output file
    write(output_fd, packed.get(), PACKED_FRAME_SIZE_BYTES);
  }
}
