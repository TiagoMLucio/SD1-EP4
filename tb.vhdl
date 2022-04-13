-------------------------------------------------------
--! @data_flow.vhdl
--! @brief Descrição de um Data Flow para o PoliStack
--! @author Tiago M Lucio (tiagolucio@usp.br)
--! @date 2021-12-16
-------------------------------------------------------

library ieee;
use ieee.numeric_bit.all;

entity tb is
end entity; 

architecture arch of tb is

    component data_flow is
        generic (
            addr_s : natural := 16; -- address size in bits
            word_s : natural := 32  -- word size in bits
        );
        port (
            clock, reset : in bit;
            -- Memory Interface
            memA_addr, memB_addr : out bit_vector(addr_s-1 downto 0);
                    memB_wrd  : out bit_vector(word_s-1 downto 0);
            memA_rdd, memB_rdd   : in bit_vector(word_s-1 downto 0);
            -- Control Unit Interface
            pc_en, ir_en, sp_en             : in bit;
            pc_src, mem_a_addr_src,
            mem_b_mem_src                   : in bit;
            mem_b_addr_src, mem_b_wrd_src,
            alu_a_src, alu_b_src            : in bit_vector(1 downto 0);
            alu_shfimm_src, alu_mem_src     : in bit;
            alu_op                          : in bit_vector(2 downto 0);
            instruction                     : out bit_vector(7 downto 0)
            );
    end component;

    signal clock, reset, pc_en, ir_en, sp_en, pc_src, mem_a_addr_src, mem_b_mem_src, alu_shfimm_src, alu_mem_src : bit;
    signal alu_op  : bit_vector(2 downto 0);
    signal instruction  : bit_vector(7 downto 0);
    signal  mem_b_addr_src, mem_b_wrd_src, alu_a_src, alu_b_src : bit_vector(1 downto 0);
    signal memA_addr, memB_addr : bit_vector(16-1 downto 0);
    signal memA_rdd, memB_rdd, memB_wrd : bit_vector(32-1 downto 0);

begin

    DUT : data_flow port map(clock, reset,memA_addr, memB_addr, memB_wrd, memA_rdd, memB_rdd,pc_en, ir_en, sp_en, pc_src, mem_a_addr_src, mem_b_mem_src,mem_b_addr_src, mem_b_wrd_src,alu_a_src, alu_b_src,alu_shfimm_src, alu_mem_src,alu_op,instruction);
    
        -- Clock generator
    clk: process is
        begin
        clock <= '0';
        wait for 0.5 ns;
        clock <= '1';
        wait for 0.5 ns;
        end process clk;  
    
    --  This process does the real job.
    stimulus_process: process is
        type pattern_type is record
            reset, pc_en, ir_en, sp_en, pc_src, mem_a_addr_src, mem_b_mem_src, alu_shfimm_src, alu_mem_src : bit;
            alu_op  : bit_vector(2 downto 0);
            instruction  : bit_vector(7 downto 0);
            mem_b_addr_src, mem_b_wrd_src, alu_a_src, alu_b_src : bit_vector(1 downto 0);
            memA_addr, memB_addr : bit_vector(16-1 downto 0);
            memA_rdd, memB_rdd, memB_wrd : bit_vector(32-1 downto 0);
        end record;

        --  The patterns to apply.
        type pattern_array is array (natural range <>) of pattern_type;
        constant patterns : pattern_array :=
        (
            ('0', '0', '0', '0', '0', '0', '0', '0', '0', "000", "00000000", "00", "00", "00", "00", "0000000000000000", "0000000000000000", "00000000000000000000000000000000", "00000000000000000000000000000000", "00000000000000000000000000000000") -- 1ns
        ); 

    begin 
        --  Check each pattern.
        for k in patterns'range loop

            --  Set the inputs.
            reset <= patterns(k).reset;
            pc_en <= patterns(k).pc_en;
            ir_en <= patterns(k).ir_en;
            sp_en <= patterns(k).sp_en;
            pc_src <= patterns(k).pc_src;
            mem_a_addr_src <= patterns(k).mem_a_addr_src;
            mem_b_mem_src <= patterns(k).mem_b_mem_src;
            alu_shfimm_src <= patterns(k).alu_shfimm_src;
            alu_mem_src <= patterns(k).alu_mem_src;
            alu_op <= patterns(k).alu_op;
            mem_b_addr_src <= patterns(k).mem_b_addr_src;
            mem_b_wrd_src <= patterns(k).mem_b_wrd_src;
            alu_a_src <= patterns(k).alu_a_src;
            alu_b_src <= patterns(k).alu_b_src;

            --  Wait for the results.
            wait for 1 ns;
            
            --  Check the outputs.
            assert instruction = patterns(k).instruction
            report "bad Ins" severity error;

            assert memA_rdd = patterns(k).memA_rdd
            report "bad memA_rdd" severity error;

            assert memB_rdd = patterns(k).memB_rdd
            report "bad memB_rdd" severity error;

            assert memB_wrd = patterns(k).memB_wrd
            report "bad memB_wrd" severity error;
        end loop;
        
        assert false report "end of test" severity note;
        
        --  Wait forever; this will finish the simalution.
        wait;
    end process;

end architecture; -- arch