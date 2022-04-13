-------------------------------------------------------
--! @file alu.vhdl
--! @brief Descrição de uma ALU
--! @author Tiago M Lucio (tiagolucio@usp.br)
--! @date 2021-11-09
-------------------------------------------------------

library ieee;
use ieee.numeric_bit.all;

entity alu is
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
end entity alu;

entity full_adder is
  port (
    A, B, Ci   : in bit;
    Co, S     : out bit
  );
end full_adder ;

architecture arch_fa of full_adder is

    begin

    Co <= (A and B) or (A and Ci) or (B and Ci);
    S <= A xor B xor Ci;

end architecture ; -- arch_fa

architecture arch of alu is

    component full_adder is
        port (
            A, B, Ci   : in bit;
            Co, S     : out bit
          );
    end component;

    signal Ainv, F_min, F_aux, F_s, B_aux, Z_aux   : bit_vector (size - 1 downto 0);
    signal Co_aux                                  : bit_vector (size downto 0);
    signal Ov_aux                                  : bit;                                               

begin

    -- Cálculo valores auxiliares

    Co_aux(0) <= S(2);

    auxF : for i in 0 to size - 1 generate
        Ainv(i) <= A(size - 1 - i);
        F_min(i) <= '0';

        with S select
            B_aux(i) <= not B(i) when "100",
                        B(i)     when others;
        
        fai: full_adder port map (A(i), B_aux(i), Co_aux(i), Co_aux(i + 1), F_s(i));

    end generate;
    -- Cálculo valores auxiliares

    -- Sáida F
    with S select
        F_aux <= A   when "000", -- A
             F_s     when "001", -- adição
             A and B   when "010", -- and
             A or B    when "011", -- or
             F_s     when "100", -- subtração
             not A    when "101", -- NOT A
             Ainv    when "110", -- inverte A
             B       when "111", -- B
             F_min   when others;

    F <= F_aux;
    -- F

    -- Zero Flag
    Z_aux(0) <= not F_aux(0);
    Z <= Z_aux(size - 1);

    auxZ : for i in 1 to size - 1 generate
        Z_aux(i) <= Z_aux(i - 1) and  not (F_aux(i)); 
    end generate;
    -- Z

    -- Overflow Flag
    Ov <= Ov_aux and (A(size - 1) xor F_aux(size - 1)); -- A e F tem sinais diferentes

    with S select
        Ov_aux <= (A(size - 1) xnor B(size - 1)) when "001", -- A e B tem mesmo sinal e é uma soma
                 (A(size - 1) xor B(size - 1))  when "100", -- A e B tem sinais diferentes e é uma subtração
                 '0'                            when others;
    -- Ov

    -- Carry Out Flag
        Co <= Co_aux(size) when S = "100" or S = "001" else
              '0';
    -- Co

end arch ; -- arch
