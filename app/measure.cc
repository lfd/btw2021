#include <cstring>

using namespace std;

/**
 * Determines whether "--async" was specified as a command line argument.
 *
 * @param argc
 * @param argv
 * @return true if "--async" is one of the command line arguments
 */
bool async_mode(int argc, char* argv[]) {
    for (int i = 1; i < argc; ++i)
        if (!strcmp(argv[i], "--async"))
            return true;
    return false;
}

/**
 * Main function that executes the sql program corresponding to the header file
 * included. If "-async" is among the command line arguments then the execution
 * is performed asynchronous in a seperate thread, otherwise it is performed in
 * the same thread. If performed in a separate thread and while not finished it
 * continuously gets snapshots of the results and prints them in xml format. At
 * the end of the execution the final results are also printed.
 *
 * @param argc
 * @param argv
 * @return
 */
int main(int argc, char* argv[]) {
    dbtoaster::Program p(argc,argv);
    dbtoaster::Program::snapshot_t snap;

    p.init();

    p.run(false);
/*    while (!p.is_finished()) {
        snap = p.get_snapshot();
        DBT_SERIALIZATION_NVP_OF_PTR(cout, snap);
    } */

    snap = p.get_snapshot();
    DBT_SERIALIZATION_NVP_OF_PTR(cout, snap);
    cout << std::endl;
    return 0;
}
