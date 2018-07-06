#include "diffie_hellman.h"
#include "modp_groups.h"
#include <stdbool.h>
#include <openssl/dh.h>
#include <string.h>

// all good?
bool diffie_verify(DH* dh) {
    int codes;
    return DH_check(dh, &codes );
}

bool diffie_init(DH* dh, const char * groupName) {
    // find group
    const modp_group* group = NULL;
    for( int i = 0; i < 8; i++ ) {
        const modp_group* mg = &modp_groups[i];
        if( strcmp( mg->name, groupName ) == 0 ) {
            group = mg;
            break;
        }
    }
    if( group == NULL )
        return false;   // failed to find group

    dh->p = BN_bin2bn(group->prime, group->prime_size, 0);
    dh->g = BN_bin2bn(group->gen, group->gen_size, 0);
    
    return diffie_verify(dh);
}

bool diffie_set_private_key(DH* dh, const unsigned char* private_key_bytes, int len) {
    dh->priv_key = BN_bin2bn(private_key_bytes, len, 0);
    
    return diffie_verify(dh);
}

// secret length of -1 means error and result pointer has error description
// if secret_length > -1, caller must free returned pointer
unsigned char * diffie_compute_secret(DH* dh, const unsigned char* public_key_bytes, int len, int* secret_length ) {
    // convert raw bytes to big number
    BIGNUM* public_key_bignum = BN_bin2bn( public_key_bytes, len, 0 );

    // buffer to store computed secret
    int secret_buffer_size = DH_size(dh);   // DH_size = bytes in prime number
    unsigned char* secret_buffer = malloc(secret_buffer_size); // new char[dataSize];
    
    // create the secret!
    *secret_length = DH_compute_key(secret_buffer, public_key_bignum, dh);
    if (*secret_length == -1) {
        int checkResult;
        int checked;
        
        checked = DH_check_pub_key(dh, public_key_bignum, &checkResult);
        BN_free(public_key_bignum);
        free( secret_buffer );
        
        if (!checked) {
            return (unsigned char *) "Invalid Key";
        } else if (checkResult) {
            if (checkResult & DH_CHECK_PUBKEY_TOO_SMALL) {
                return (unsigned char *)"Supplied key is too small";
            } else if (checkResult & DH_CHECK_PUBKEY_TOO_LARGE) {
                return (unsigned char *)"Supplied key is too large";
            } else {
                return (unsigned char *)"Invalid key";
            }
        } else {
            return (unsigned char *)"Invalid key";
        }
    }
    
    BN_free(public_key_bignum);
    return secret_buffer;   // caller MUST free this!
}

