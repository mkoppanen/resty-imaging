//
// imaging.c 
//

#include <vips/vips8>
#include <string>
#include <vector>
#include <iostream>
#include <cstdlib>
#include <cmath>

using namespace vips;

#define ROUND_MASK "<svg><rect x=\"0\" y=\"0\" width=\"%d\" height=\"%d\" rx=\"%d\" ry=\"%d\"/></svg>"


static
int s_image_alpha_max(VipsInterpretation interpretation) {

    if (interpretation == VIPS_INTERPRETATION_RGB16 ||
        interpretation == VIPS_INTERPRETATION_GREY16) {
        return 65535;
    }
    return 255;
}

static
VImage s_image_split(VImage in, VImage &alpha, bool &has_alpha)
{
    VImage image;

    if( in.bands() == 2 || 
        (in.bands() == 4 && 
         in.interpretation() != VIPS_INTERPRETATION_CMYK ) ||
        (in.bands() == 5 && 
         in.interpretation() == VIPS_INTERPRETATION_CMYK ) ) {
        has_alpha = TRUE;
        image = in.extract_band( 0, 
            VImage::option()->set( "n", in.bands() - 1 ) );
        alpha = in.extract_band( in.bands() - 1,
            VImage::option()->set( "n", 1 ) );
    }
    else {
        has_alpha = FALSE;
        image = in;
    }

    return( image );
}

enum ResizeMode { 
    ResizeModeFill,
    ResizeModeFit,
    ResizeModeCrop,
};

enum Gravity {
    GravityNorth,
    GravityNorthEast,
    GravityEast,
    GravitySouthEast,
    GravitySouth,
    GravitySouthWest,
    GravityWest,
    GravityNorthWest,
    GravityCenter,
    GravitySmart,
};

static void *
s_suffix_list(VipsFormatClass *format, std::list<const char *> *list, void *b)
{
    if (format->suffs) {
        const char **ptr;
        for (ptr = format->suffs; *ptr; ptr++) {
            list->push_back((*ptr) + 1);
        }
    }

    return NULL;
}

class Imaging {

private:
    VImage image;
    double r, g, b;
    bool interlace;

public:

    static std::list<const char *> get_formats() {
        std::list<const char *> l;
        vips_format_map((VipsSListMap2Fn) s_suffix_list, &l, NULL);

        return l;
    }

    Imaging(VImage img);

    int get_width() {
        return this->image.width();
    }

    int get_height() {
        return this->image.height();
    }

    bool resize(int width, int height, ResizeMode mode);

    bool crop(int width, int height, Gravity gravity);

    bool round(int x, int y);

    bool blur(double sigma);

    bool set_background_colour(int r, int g, int b);

    void *to_buffer(const std::string& format, int quality, bool strip, size_t *len);

    ~Imaging();
};

Imaging::Imaging(VImage img) {
    this->image = img;
    this->r = 255.0;
    this->g = 255.0;
    this->b = 255.0;
    this->interlace = true;
}

bool Imaging::resize(int width, int height, ResizeMode mode) {

    int image_width  = this->image.width();
    int image_height = this->image.height();

    if (mode == ResizeModeFit || mode == ResizeModeFill) {

        double scale = 0.0;

        if (width > 0 && height > 0) {
            double ratio_x = ((double) width + 0.1) / (double) image_width;
            double ratio_y = ((double) height + 0.1) / (double) image_height;

            scale = (ratio_x < ratio_y) ? ratio_x : ratio_y;
        }
        else if (width > 0) {
            scale = ((double) width + 0.1) / (double) image_width;
        }
        else {
            scale = ((double) height + 0.1) / (double) image_height;
        }

        this->image = this->image.resize(scale, NULL);

        if (mode == ResizeModeFill) {

            if (this->image.width() < width || this->image.height() < height) {

                int w = (this->image.width() < width)   ? std::round((width - this->image.width()) / 2)   : 0;
                int h = (this->image.height() < height) ? std::round((height - this->image.height()) / 2) : 0;

                this->image = this->image.embed(
                    w,
                    h,
                    width,
                    height, 
                    VImage::option()
                        ->set("extend", VIPS_EXTEND_BACKGROUND)
                        ->set("background", to_vectorv(4, this->r, this->g, this->b, 0))
                );

            }
        }
        return true;
    }
    else if (mode == ResizeModeCrop) {

        double ratio_x = ((double) width + 0.1) / (double) image_width;
        double ratio_y = ((double) height + 0.1) / (double) image_height;

        double scale = (ratio_x > ratio_y) ? ratio_x : ratio_y;
        this->image = this->image.resize(scale, NULL);

        return this->crop(width, height, GravityCenter);

    }

    return false;
}

bool Imaging::crop(int width, int height, Gravity gravity) {

    int image_width  = this->image.width();
    int image_height = this->image.height();

    if (!width) {
        width = image_width;
    }
    else {
        if (image_width < width) {
            width = image_width;
        }
    }

    if (!height) {
        height = image_height;
    }
    else {
        if (image_height < height) {
            height = image_height;
        }
    }

    if (image_width == width && image_height == height) {
        return true;
    }

    int x = 0, y = 0;

    switch (gravity) {
        case GravityNorth:
            x = (image_width - width) / 2 + 0.1;
            y = 0;

            break;

        case GravityNorthEast:
            x = (image_width - width);
            y = 0;

            break;

        case GravityEast:
            x = (image_width - width);
            y = (image_height - height) / 2 + 0.1;

            break;

        case GravitySouthEast:
            x = (image_width - width);
            y = (image_height - height);

            break;

        case GravitySouth:
            x = (image_width - width) / 2 + 0.1;
            y = (image_height - height);

            break;

        case GravitySouthWest:
            x = 0;
            y = (image_height - height);

            break;

        case GravityWest:
            x = 0;
            y = (image_height - height) / 2 + 0.1;

            break;

        case GravityNorthWest:
            x = 0;
            y = 0;

            break;

        case GravityCenter:
            x = (image_width - width) / 2 + 0.1;
            y = (image_height - height) / 2 + 0.1;

            break;

        case GravitySmart:

            this->image = this->image.smartcrop(width, height);
            return true;
    }

    this->image = this->image.extract_area(x, y, width, height);
    return true;
}


bool Imaging::round(int x, int y) {

    size_t buf_max = sizeof (ROUND_MASK) * 2;

    char buf[buf_max];
    size_t buf_len;

    buf_len = sprintf(buf, ROUND_MASK, this->image.width(), this->image.height(), x, y);

    VImage image_alpha;
    bool image_has_alpha;
    VImage image = s_image_split(this->image, image_alpha, image_has_alpha);

    // load the mask image
    VImage in2 = VImage::new_from_buffer(buf, buf_len, NULL, NULL);
    VImage mask_alpha;
    bool mask_has_alpha;
    VImage mask = s_image_split(in2, mask_alpha, mask_has_alpha );

    // we use the mask alpha, or if the mask only has one band, use that
    if (mask_has_alpha) {
        mask = mask_alpha;
    }

    // the range of the mask and the image need to match .. one could be
    // 16-bit, one 8-bit
    int image_max = s_image_alpha_max(image.interpretation());
    int mask_max = s_image_alpha_max(mask.interpretation()); 

    if (image_has_alpha) {
        // combine the new mask and the existing alpha ... there are 
        // many ways of doing this, mult is the simplest
        mask = image_max * ((mask / mask_max) * (image_alpha / image_max));
    } 
    else if( image_max != mask_max ) {
        // adjust the range of the mask to match the image
        mask = image_max * (mask / mask_max);
    }

    // append the mask to the image data ... the mask might be float now,
    // we must cast the format down to match the image data
    this->image = image.bandjoin(mask.cast(image.format()));
    
    return true;
}

bool Imaging::blur(double sigma)
{
    this->image = this->image.gaussblur(sigma, NULL);
    return true;
}

bool Imaging::set_background_colour(int r, int g, int b)
{
    this->r = r;
    this->g = g;
    this->b = b;
    return true;
}

void *Imaging::to_buffer(const std::string& format, int quality, bool strip, size_t *len)
{
    void *buf = NULL;

    VOption *options = (
        VImage::option()
            ->set("strip",      strip)
            ->set("interlace",  this->interlace)
            ->set("background", to_vectorv(3, this->r, this->g, this->b))
    );

    if (format == ".jpg" || format == ".jpeg") {
        options->set("Q", quality);
    }

    this->image.write_to_buffer(
        format.c_str(),
        &buf,
        len,
        options
    );
    return buf;
}


Imaging::~Imaging() {

}

extern "C" {

    static
        char **s_format_list = NULL;

    static
        size_t s_num_formats = 0;

    bool imaging_ginit(const char *name, int concurrency) {
        vips_concurrency_set(concurrency);
        bool rc = VIPS_INIT(name) == 0;

        if (rc) {
            std::list<const char *> formats = Imaging::get_formats();

            s_format_list = (char **) calloc(formats.size(), sizeof (char *));
            s_num_formats = formats.size();

            int i = 0;

            for (std::list<const char *>::iterator it = formats.begin(); it != formats.end(); ++it) {
                s_format_list[i++] = strdup(*it);
            }
        }

        return rc;
    }

    const char **imaging_get_formats(size_t *len) {
        *len = s_num_formats;
        return (const char **) s_format_list;
    }

    void imaging_gshutdown() {

        if (s_format_list) {
            size_t i;
            for (i = 0; i < s_num_formats; i++) {
                free(s_format_list[i]);
            }
            free(s_format_list);
        }

        vips_shutdown();
    }

    Imaging *Imaging_new_from_buffer(void *buf, size_t len) {

        try {

            VImage img = VImage::new_from_buffer(
                buf,
                len,
                NULL,
                NULL
            );
            
            return new Imaging(img);

        } catch(VError &e) {
            e.ostream_print(std::cerr);
            return NULL;
        }
    }

    bool Imaging_resize(Imaging *img, int width, int height, ResizeMode mode) {
 
        try {
            return img->resize(width, height, mode);
        } catch(VError &e) {
            e.ostream_print(std::cerr);
            return false;
        }
    }

    bool Imaging_crop(Imaging *img, int width, int height, Gravity gravity) {
        
        try {
            return img->crop(width, height, gravity);
        } catch(VError &e) {
            e.ostream_print(std::cerr);
            return false;
        }  
    }

    bool Imaging_blur(Imaging *img, double sigma) {
        try {
            return img->blur(sigma);
        } catch(VError &e) {
            e.ostream_print(std::cerr);
            return false;
        }
    }

    int Imaging_get_width(Imaging *img) {
        return img->get_width();
    }

    int Imaging_get_height(Imaging *img) {
        return img->get_height();
    }

    bool Imaging_round(Imaging *img, int x, int y) {

        try {
            return img->round(x, y);
        } catch(VError &e) {
            e.ostream_print(std::cerr);
            return false;
        }
    }

    bool Imaging_set_background_colour(Imaging *img, int r, int g, int b) {
        return img->set_background_colour(r, g, b);
    }

    void *Imaging_to_buffer(Imaging *img, const char *format, int quality, bool strip, size_t *len) {
 
        try {
            return img->to_buffer(std::string(format), quality, strip, len);
        } catch(VError &e) {
            e.ostream_print(std::cerr);
            return NULL;
        }
    }

    void Imaging_gc(Imaging *img) {
        delete img;
    }

    void Imaging_gc_buffer(void *buf) {
        g_free(buf);
    }
};


