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

    component buffer1
    port (
      D : in  std_logic;
      Q : out std_logic
    );
    end component buffer1;

begin
  my_buffer_i : buffer1
  port map (
    D => D,
    Q => Q
  );

end architecture;
