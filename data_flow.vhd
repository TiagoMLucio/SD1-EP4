-------------------------------------------------------
--! @data_flow.vhdl
--! @brief Descrição de um Data Flow para o PoliStack
--! @author Tiago M Lucio (tiagolucio@usp.br)
--! @date 2021-12-16
-------------------------------------------------------

library ieee;
use ieee.numeric_bit.all;

entity data_flow is
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
end entity; 

architecture arch of data_flow is

    component alu is
        generic (
            size : natural := 8
        );
        port (
            A, B    : in bit_vector(size - 1 downto 0); -- inputs
            F       : out bit_vector(size - 1 downto 0); -- output
            S       : in bit_vector(2 downto 0); -- op selection
            Z       : out bit; -- zero flag
            Ov      : out bit; -- overflow flag
            Co      : out bit -- carry out
        );
    end component;

    component d_register
        generic (
            width       : natural := 6;
            reset_value : natural := 0
        );
        port (
            clock, reset, load  : in bit;
            d                   : in bit_vector(width - 1 downto 0);
            q                   : out bit_vector(width - 1 downto 0)
        );
    end component;

    signal ir3, ir3_f, ir4, ir6, ir6_se     : bit_vector(word_s-1 downto 0);
    signal alu_o, alu_a, alu_b              : bit_vector(word_s-1 downto 0);
    signal d_pc                             : bit_vector(word_s-1 downto 0);
    signal pc, sp                           : bit_vector(word_s-1 downto 0);
    signal imm_shft, memb_mem, alu_mem      : bit_vector(word_s-1 downto 0);
    signal ir                               : bit_vector(7 downto 0);

begin

    alum : alu generic map (word_s)
                port map (alu_a, alu_b, alu_o, alu_op, open, open, open);

    pcm : d_register generic map (word_s, 0)
                    port map (clock, reset, pc_en, d_pc, pc);

    spm : d_register generic map (word_s, 131064)
                    port map (clock, reset, sp_en, alu_o, sp);

    irm : d_register generic map (8, 0)
                    port map (clock, reset, ir_en, memA_rdd(7 downto 0), ir);


    aux_ir : for i in word_s-1 downto 0 generate
        ir_3i : if (i <= 3) generate
            ir3(i) <= ir(i);
        end generate;
        ir_3e : if (i > 3) generate
            ir3(i) <= '0';
        end generate;

        ir_4i : if (i <= 4) generate
            ir4(i) <= ir(i);
        end generate;
        ir_4e : if (i > 4) generate
            ir4(i) <= '0';
        end generate;

        ir_6i : if (i <= 6) generate
            ir6(i) <= ir(i);
            ir6_se(i) <= ir(i);
        end generate;
        ir_6e : if (i > 6) generate
            ir6(i) <= '0';
            ir6_se(i) <= ir(6);
        end generate;
        
    end generate;
            
    aux_ir3 : for i in word_s-1 downto 0 generate
        ir3_1 : if (i <= 1) generate
            ir3_f(i) <= '0';
        end generate;
        ir3_2 : if (i > 1 and i <= 5) generate
            ir3_f(i) <= ir3(i-2);
        end generate;
        ir3_3 : if (i = 6) generate
            ir3_f(i) <= not ir(4);
        end generate;
        ir3_4 : if (i > 6) generate
            ir3_f(i) <= '0';
        end generate;
    end generate;

    with pc_src select
        d_pc <= alu_o     when '0',
                memA_rdd  when '1';
    
    with mem_a_addr_src select
        memA_addr <= sp(addr_s-1 downto 0) when '0',
                     pc(addr_s-1 downto 0) when '1';  

    with mem_b_addr_src select
        memB_addr <= sp(addr_s-1 downto 0)          when "00",
                     memA_rdd(addr_s-1 downto 0)    when "01",
                     alu_o(addr_s-1 downto 0)       when others;

    with mem_b_wrd_src select
        memB_wrd <= alu_o       when "00",
                    memb_mem    when "01",
                    sp          when "10",
                    ir6_se      when "11";

    with mem_b_mem_src select
        memb_mem <= memA_rdd when '0',
                    memB_rdd when '1';

    with alu_a_src select
        alu_a <= pc         when "00",
                 sp         when "01",
                 memA_rdd   when others;
    
    with alu_b_src select
        alu_b <= imm_shft                                       when "00",
                 alu_mem                                        when "01",
                 ir4(word_s-6 downto 0) & "00000"               when "10",
                 ir3_f                                          when "11";

    with alu_shfimm_src select
        imm_shft <= bit_vector(to_unsigned(1, word_s)) when '0',
                    bit_vector(to_unsigned(4, word_s)) when '1';
    
    with alu_mem_src select
        alu_mem <= memA_rdd(word_s-8 downto 0) & "0000000" or ir6   when '0',
                   memB_rdd                                         when '1';

    instruction <= ir;

end architecture; -- arch