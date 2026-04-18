#ifndef ELEMENT_H
#define ELEMENT_H

#include <cstdint>

#define QUEUE_CAPACITY 16
#define PROD_MIN 64
#define PROD_MAX 1128

struct Element {
    char type;
    uint8_t value;
};

#endif
