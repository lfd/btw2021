#include <cstring>

using namespace std;

/**
 * Main function that executes the sql program corresponding to the header file
 * included, based on the DBToaster example code.
 */
int main(int argc, char* argv[]) {
    dbtoaster::Program p(argc,argv);
    dbtoaster::Program::snapshot_t snap;

    p.init();

    p.run(false);
    snap = p.get_snapshot();
    p.print_log_buffer();

    return 0;
}
