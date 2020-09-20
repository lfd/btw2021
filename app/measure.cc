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
    DBT_SERIALIZATION_NVP_OF_PTR(cout, snap);
    cout << std::endl;
    return 0;
}
