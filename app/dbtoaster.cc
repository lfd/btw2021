#include <rtems.h>
#include <rtems/ramdisk.h>
#include <rtems/untar.h>
#include <rtems/printer.h>

#include <cstdlib>
#include <cstdlib>
#include <iostream>
using namespace std;

// TODO: These two definition should come from fs-root-tar.h, which
// is in the binary build folder. Check how it's supposed to be
// retrieved from there.
extern const unsigned char fs_root_tar[];
extern const size_t fs_root_tar_size;

extern int main(int argc, char **argv);

// TODO: Size this properly depending on the actual amount of data
rtems_ramdisk_config rtems_ramdisk_configuration[] =
{
  {
    .block_size = 512,
    .block_num = 80*1024*1024
  }
};

size_t rtems_ramdisk_configuration_size = 1;

extern "C" {
rtems_task Init(
  rtems_task_argument ignored
)
{
  cout << "Welcome to DBToaster@RTEMS" << endl;
  cout << "Populating filesystem" << endl;

  struct rtems_printer prt;
  
  rtems_print_printer_printf (&prt);
  int res = Untar_FromMemory_Print((char*) fs_root_tar, fs_root_tar_size, &prt);
  if (res != 0) {
     cout << "Internal error: Can't unpack tar filesystem: " <<  res << endl;
     exit(1);
   }

   cout << "Running DBToaster proper" << endl;

   // Dispatch somewhat clumsily via main routine so that
   // we use identical core measurement code on Linux and RTEMS
   char *argv[] = { const_cast<char*>("dbtoaster"),
                    const_cast<char*>("--log-count=1")
                   } ;
   main(2, argv);

   cout << "DBToaster finished" << endl;

   exit(0);
}
}
