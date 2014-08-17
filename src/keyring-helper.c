#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "gnome-keyring.h"

#define REPORT_KEYRING_ERROR(err_val)  do { \
fprintf(stderr, "Boxen Keyring Helper: Encountered gnome keyring error code: %d at %d:%s\n", err_val,__LINE__,__FILE__); \
fprintf(stderr, "Error: %s\n", gnome_keyring_result_to_message(err_val)); \
} while(0)

GnomeKeyringPasswordSchema GenericPassword = {
  GNOME_KEYRING_ITEM_CHAINED_KEYRING_PASSWORD,
  {
    { "service", GNOME_KEYRING_ATTRIBUTE_TYPE_STRING },
    { "account", GNOME_KEYRING_ATTRIBUTE_TYPE_STRING },
    { NULL, 0 }
  }
};

int key_exists_p(
  const char* service,
  const char* login,
  char* item
) {

  GnomeKeyringResult ret = gnome_keyring_find_password_sync(&GenericPassword, &item, "service", service, "account", login, NULL);
  
  gnome_keyring_free_password(item);
  if (ret == GNOME_KEYRING_RESULT_OK) {
    return 0;
  } else {
    if (ret != GNOME_KEYRING_RESULT_NO_MATCH) {
       // Item not found is not an error in predicate method context.
       REPORT_KEYRING_ERROR(ret);
    }
    return ret;
  }
}

int main(int argc, char** argv) {
  if ((argc < 3) || (argc > 4)) {
    printf("Usage: %s <service> <account> [<password>]\n", argv[0]);
    return 1;
  }

  const char* service  = argv[1];
  const char* login    = argv[2];
  const char* password = argc == 4 ? argv[3] : NULL;

  char* item = NULL;

  if (password != NULL && strlen(password) != 0) {
    if (key_exists_p(service, login, item) == 0) {
      gnome_keyring_delete_password_sync(&GenericPassword, "service", service, "account", login, NULL);
    }

    GnomeKeyringResult create_key = gnome_keyring_store_password_sync(&GenericPassword, NULL, service, password, "service", service, "account", login, NULL);

    if (create_key != 0) {
      REPORT_KEYRING_ERROR(create_key);
      return 1;
    }
  } else if (password != NULL && strlen(password) == 0) {
    if (key_exists_p(service, login, item) == 0) {
      GnomeKeyringResult ret = gnome_keyring_delete_password_sync(&GenericPassword, "service", service, "account", login, NULL);
      if (ret != GNOME_KEYRING_RESULT_OK) {
        REPORT_KEYRING_ERROR(ret);
      }
    }
  } else {
    GnomeKeyringResult find_key = gnome_keyring_find_password_sync(&GenericPassword, &item, "service", service, "account", login, NULL);

    if (find_key == GNOME_KEYRING_RESULT_NO_MATCH) {
      return find_key;
    }
    if (find_key != 0) {
      REPORT_KEYRING_ERROR(find_key);
      return 1;
    }

    fwrite(item, 1, strlen(item), stdout);
    gnome_keyring_free_password(item);
  }

  return 0;
}
