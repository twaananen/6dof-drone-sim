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

static void emit_event(int fd, uint16_t type, uint16_t code, int32_t value) {
    struct input_event ev;
    memset(&ev, 0, sizeof(ev));
    ev.type = type;
    ev.code = code;
    ev.value = value;
    write(fd, &ev, sizeof(ev));
}

static int create_device(void) {
    int fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (fd < 0) {
        perror("open(/dev/uinput)");
        return -1;
    }

    ioctl(fd, UI_SET_EVBIT, EV_ABS);
    ioctl(fd, UI_SET_ABSBIT, ABS_X);
    ioctl(fd, UI_SET_ABSBIT, ABS_Y);
    ioctl(fd, UI_SET_ABSBIT, ABS_RX);
    ioctl(fd, UI_SET_ABSBIT, ABS_RY);
    ioctl(fd, UI_SET_ABSBIT, ABS_Z);
    ioctl(fd, UI_SET_ABSBIT, ABS_RZ);

    ioctl(fd, UI_SET_EVBIT, EV_KEY);
    ioctl(fd, UI_SET_KEYBIT, BTN_SOUTH);
    ioctl(fd, UI_SET_KEYBIT, BTN_EAST);
    ioctl(fd, UI_SET_KEYBIT, BTN_WEST);
    ioctl(fd, UI_SET_KEYBIT, BTN_NORTH);

    struct uinput_setup setup;
    memset(&setup, 0, sizeof(setup));
    snprintf(setup.name, UINPUT_MAX_NAME_SIZE, "6DOF Drone Controller");
    setup.id.bustype = BUS_USB;
    setup.id.vendor = 0x6D0F;
    setup.id.product = 0x0001;
    setup.id.version = 1;
    ioctl(fd, UI_DEV_SETUP, &setup);

    struct uinput_abs_setup abs_setup;
    memset(&abs_setup, 0, sizeof(abs_setup));
    abs_setup.absinfo.minimum = -ABS_MAX_VAL;
    abs_setup.absinfo.maximum = ABS_MAX_VAL;
    abs_setup.absinfo.fuzz = 0;
    abs_setup.absinfo.flat = 0;

    int abs_codes[] = {ABS_X, ABS_Y, ABS_RX, ABS_RY, ABS_Z, ABS_RZ};
    for (int i = 0; i < 6; i++) {
        abs_setup.code = abs_codes[i];
        ioctl(fd, UI_ABS_SETUP, &abs_setup);
    }

    if (ioctl(fd, UI_DEV_CREATE) < 0) {
        perror("UI_DEV_CREATE");
        close(fd);
        return -1;
    }
    return fd;
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
    fcntl(sockfd, F_SETFL, flags | O_NONBLOCK);
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
            int value = (int)(axis * ABS_MAX_VAL);
            if (value > ABS_MAX_VAL) value = ABS_MAX_VAL;
            if (value < -ABS_MAX_VAL) value = -ABS_MAX_VAL;
            emit_event(device_fd, EV_ABS, abs_codes[i], value);
        }

        uint16_t buttons = 0;
        memcpy(&buttons, packet + 28, sizeof(uint16_t));
        for (int i = 0; i < 4; i++) {
            emit_event(device_fd, EV_KEY, button_codes[i], (buttons >> i) & 1);
        }
        emit_event(device_fd, EV_SYN, SYN_REPORT, 0);
    }

    ioctl(device_fd, UI_DEV_DESTROY);
    close(device_fd);
    close(sockfd);
    return 0;
}

