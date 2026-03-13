#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/uinput.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#define DEFAULT_PORT 9102
#define ABS_MAX_VAL 32767
#define PACKET_SIZE 30

static volatile int running = 1;

static void handle_signal(int sig) {
    (void)sig;
    running = 0;
}

static int emit_event(int fd, uint16_t type, uint16_t code, int32_t value) {
    struct input_event ev;
    memset(&ev, 0, sizeof(ev));
    ev.type = type;
    ev.code = code;
    ev.value = value;
    ssize_t written = write(fd, &ev, sizeof(ev));
    if (written < 0) {
        perror("write(input_event)");
        return -1;
    }
    if ((size_t)written != sizeof(ev)) {
        fprintf(stderr, "write(input_event): short write\n");
        return -1;
    }
    return 0;
}

static int ioctl_value(int fd, unsigned long request, unsigned long value, const char *label) {
    if (ioctl(fd, request, value) < 0) {
        perror(label);
        return -1;
    }
    return 0;
}

static int ioctl_ptr(int fd, unsigned long request, void *value, const char *label) {
    if (ioctl(fd, request, value) < 0) {
        perror(label);
        return -1;
    }
    return 0;
}

static int open_uinput_device(void) {
    const char *paths[] = {"/dev/uinput", "/dev/input/uinput"};
    int last_errno = 0;
    for (size_t i = 0; i < sizeof(paths) / sizeof(paths[0]); i++) {
        int fd = open(paths[i], O_WRONLY | O_NONBLOCK);
        if (fd >= 0) {
            return fd;
        }
        last_errno = errno;
    }
    errno = last_errno;
    perror("open(uinput)");
    return -1;
}

static int scale_stick_axis(float axis) {
    if (axis > 1.0f) axis = 1.0f;
    if (axis < -1.0f) axis = -1.0f;
    return (int)(axis * ABS_MAX_VAL);
}

static int scale_trigger_axis(float axis) {
    if (axis < 0.0f) axis = 0.0f;
    if (axis > 1.0f) axis = 1.0f;
    return (int)(axis * ABS_MAX_VAL);
}

static int create_device(void) {
    int fd = open_uinput_device();
    if (fd < 0) {
        return -1;
    }

    if (ioctl_value(fd, UI_SET_EVBIT, EV_ABS, "UI_SET_EVBIT EV_ABS") < 0) {
        goto fail;
    }
    int abs_codes[] = {ABS_X, ABS_Y, ABS_RX, ABS_RY, ABS_Z, ABS_RZ};
    for (size_t i = 0; i < sizeof(abs_codes) / sizeof(abs_codes[0]); i++) {
        if (ioctl_value(fd, UI_SET_ABSBIT, (unsigned long)abs_codes[i], "UI_SET_ABSBIT") < 0) {
            goto fail;
        }
    }

    if (ioctl_value(fd, UI_SET_EVBIT, EV_KEY, "UI_SET_EVBIT EV_KEY") < 0) {
        goto fail;
    }
    int button_codes[] = {BTN_SOUTH, BTN_EAST, BTN_WEST, BTN_NORTH};
    for (size_t i = 0; i < sizeof(button_codes) / sizeof(button_codes[0]); i++) {
        if (ioctl_value(fd, UI_SET_KEYBIT, (unsigned long)button_codes[i], "UI_SET_KEYBIT") < 0) {
            goto fail;
        }
    }

    struct uinput_setup setup;
    memset(&setup, 0, sizeof(setup));
    snprintf(setup.name, UINPUT_MAX_NAME_SIZE, "6DOF Drone Controller");
    setup.id.bustype = BUS_USB;
    setup.id.vendor = 0x6D0F;
    setup.id.product = 0x0001;
    setup.id.version = 1;
    if (ioctl_ptr(fd, UI_DEV_SETUP, &setup, "UI_DEV_SETUP") < 0) {
        goto fail;
    }

    struct uinput_abs_setup abs_setup;
    memset(&abs_setup, 0, sizeof(abs_setup));
    abs_setup.absinfo.fuzz = 0;
    abs_setup.absinfo.flat = 0;

    for (size_t i = 0; i < sizeof(abs_codes) / sizeof(abs_codes[0]); i++) {
        abs_setup.code = abs_codes[i];
        if (abs_codes[i] == ABS_Z || abs_codes[i] == ABS_RZ) {
            abs_setup.absinfo.minimum = 0;
            abs_setup.absinfo.maximum = ABS_MAX_VAL;
        } else {
            abs_setup.absinfo.minimum = -ABS_MAX_VAL;
            abs_setup.absinfo.maximum = ABS_MAX_VAL;
        }
        if (ioctl_ptr(fd, UI_ABS_SETUP, &abs_setup, "UI_ABS_SETUP") < 0) {
            goto fail;
        }
    }

    if (ioctl_value(fd, UI_DEV_CREATE, 0, "UI_DEV_CREATE") < 0) {
        goto fail;
    }
    return fd;

fail:
    close(fd);
    return -1;
}

static int create_socket(int port) {
    int sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sockfd < 0) {
        perror("socket");
        return -1;
    }

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = inet_addr("127.0.0.1");
    addr.sin_port = htons((uint16_t)port);

    if (bind(sockfd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("bind");
        close(sockfd);
        return -1;
    }

    int flags = fcntl(sockfd, F_GETFL, 0);
    if (flags < 0) {
        perror("fcntl(F_GETFL)");
        close(sockfd);
        return -1;
    }
    if (fcntl(sockfd, F_SETFL, flags | O_NONBLOCK) < 0) {
        perror("fcntl(F_SETFL)");
        close(sockfd);
        return -1;
    }
    return sockfd;
}

static float read_f32(const uint8_t *buffer, int offset) {
    float value;
    memcpy(&value, buffer + offset, sizeof(float));
    return value;
}

int main(int argc, char **argv) {
    int port = DEFAULT_PORT;
    if (argc > 1) {
        port = atoi(argv[1]);
    }

    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);

    int device_fd = create_device();
    if (device_fd < 0) {
        return 1;
    }

    int sockfd = create_socket(port);
    if (sockfd < 0) {
        ioctl(device_fd, UI_DEV_DESTROY);
        close(device_fd);
        return 1;
    }

    uint8_t packet[PACKET_SIZE];
    const int abs_codes[] = {ABS_X, ABS_Y, ABS_RX, ABS_RY, ABS_Z, ABS_RZ};
    const int button_codes[] = {BTN_SOUTH, BTN_EAST, BTN_WEST, BTN_NORTH};

    while (running) {
        ssize_t received = recv(sockfd, packet, sizeof(packet), 0);
        if (received < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                usleep(1000);
                continue;
            }
            if (errno == EINTR) {
                continue;
            }
            perror("recv");
            break;
        }

        if (received != PACKET_SIZE || memcmp(packet, "GPD1", 4) != 0) {
            continue;
        }

        for (int i = 0; i < 6; i++) {
            float axis = read_f32(packet, 4 + i * 4);
            int value = (i < 4) ? scale_stick_axis(axis) : scale_trigger_axis(axis);
            if (emit_event(device_fd, EV_ABS, abs_codes[i], value) < 0) {
                running = 0;
                break;
            }
        }
        if (!running) {
            break;
        }

        uint16_t buttons = 0;
        memcpy(&buttons, packet + 28, sizeof(uint16_t));
        for (int i = 0; i < 4; i++) {
            if (emit_event(device_fd, EV_KEY, button_codes[i], (buttons >> i) & 1) < 0) {
                running = 0;
                break;
            }
        }
        if (!running) {
            break;
        }
        if (emit_event(device_fd, EV_SYN, SYN_REPORT, 0) < 0) {
            break;
        }
    }

    if (ioctl_value(device_fd, UI_DEV_DESTROY, 0, "UI_DEV_DESTROY") < 0) {
        close(device_fd);
        close(sockfd);
        return 1;
    }
    close(device_fd);
    close(sockfd);
    return 0;
}
