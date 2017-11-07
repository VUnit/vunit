library ieee;
use ieee.std_logic_1164.all;

entity buffer1 is
  port (
    D : in std_logic;
    Q : out std_logic
  );
end entity;

architecture arch of buffer1 is

begin
    Q <= D;
end architecture;

library ieee;
use ieee.std_logic_1164.all;

entity buffer2 is
  port (
    D : in std_logic;
    Q : out std_logic
  );
end entity;

architecture arch of buffer2 is

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
