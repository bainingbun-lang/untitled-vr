extern "C" {
extern void *__dso_handle;
int __register_atfork(void (*prepare)(void), void (*parent)(void), void (*child)(void), void *dso_handle);
int pthread_atfork(void (*prepare)(void), void (*parent)(void), void (*child)(void)) {
    return __register_atfork(prepare, parent, child, __dso_handle);
}
}
