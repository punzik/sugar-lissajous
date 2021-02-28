`ifndef _ASSERT_VH_
`define _ASSERT_VH_

`define assert(assertion)                                  \
    if (!(assertion)) begin                                \
        $error("ERROR: Assertion failed in %m: assertion");\
    end

`endif
