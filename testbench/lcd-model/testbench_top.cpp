#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <libgen.h>

#include <verilated_vcd_c.h>
#include "Vtestbench_top.h"

#define DUMPFILE            "testbench_top.vcd"
#define PIPE_FILE           "lcd_pipe"

/* Clock period in timescale units
 * In datapath.sv uses 100ps time unit */
#define CLOCK_PERIOD        2
#define TIMESCALE           20000

/* Simulation time */
uint64_t simtime = 0;

/* Clock cycle counter */
uint64_t cycle = 0;

/* Called by $time in Verilog */
double sc_time_stamp() {
    return simtime;
}


int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);

    /* Create model instance */
    Vtestbench_top *dp = new Vtestbench_top;

    /* Enable trace if compiled with --trace flag */
#if (VM_TRACE == 1)
    VerilatedVcdC *vcd = NULL;
    const char* trace_flag = Verilated::commandArgsPlusMatch("trace");

    if (trace_flag && (strcmp(trace_flag, "+trace") == 0))
    {
        Verilated::traceEverOn(true);
        vcd = new VerilatedVcdC;
        dp->trace(vcd, 99);
        vcd->open(DUMPFILE);
    }
#endif

    /* Open pipe */
    FILE *o_file = fopen(PIPE_FILE, "w");
    if (!o_file) {
        printf("ERROR: Can't open file/pipe '%s'\n", PIPE_FILE);
        delete dp;
        return -1;
    }

    int posedge_clock = 0;

    int data_loops = 6;
    uint64_t check_cycle;

    /* Initial */
    dp->reset = 1;
    dp->clock = 0;

    while (!Verilated::gotFinish())
    {
        posedge_clock = 0;
        if ((simtime % (CLOCK_PERIOD/2)) == 0) {
            dp->clock = !dp->clock;
            if (dp->clock) {
                posedge_clock = 1;
                cycle ++;
            }
        }

        /* release reset at 200 simulation cycle */
        if (simtime == 200) dp->reset = 0;

        dp->eval();

        /* ouput data */
        if (posedge_clock && !dp->reset && dp->strobe)
            fprintf(o_file, "%i %i %i %i %i\n",
                    dp->x, dp->y, dp->r << 2, dp->g << 2, dp->b << 2);

#if (VM_TRACE == 1)
        if (vcd)
            vcd->dump(simtime * TIMESCALE);
#endif

        simtime ++;
    }

    dp->final();
    printf("[%lu] Stop simulation\n", simtime);

#if (VM_TRACE == 1)
    if (vcd) vcd->close();
#endif

    fclose(o_file);
    delete dp;

    return 0;
}
