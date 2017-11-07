module buffer (
  input   D, //active pixels number per line, only used for "Streaming-S" mode
  output   Q
  );

assign Q = D;

endmodule
