#ifndef diffie_hellman_h
#define diffie_hellman_h

#include <stdbool.h>

/* https://www.anintegratedworld.com/mac-osx-fatal-error-opensslsha-h-file-not-found/ */
#include <openssl/dh.h>

bool diffie_init(DH* dh, const char* groupName);
bool diffie_set_private_key(DH* dh, const unsigned char* key, int len);
unsigned char * diffie_compute_secret(DH* dh, const unsigned char* public_key_bytes, int len, int* secret_length );

#endif /* diffie_hellman_h */
