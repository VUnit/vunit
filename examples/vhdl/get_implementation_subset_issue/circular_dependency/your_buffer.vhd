library ieee;
use ieee.std_logic_1164.all;

library lib_A;

entity your_buffer is
  port (
    D : in std_logic;
    Q : out std_logic
  );
end entity;

architecture arch of your_buffer is

begin
  my_buffer_i : entity lib_A.buffer1
  port map (
    D => D,
    Q => Q
  );

end architecture;
