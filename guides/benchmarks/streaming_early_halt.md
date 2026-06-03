Benchmark

Benchmark run from 2026-06-03 12:13:25.160934Z UTC

## System

Benchmark suite executing on the following system:

<table style="width: 1%">
  <tr>
    <th style="width: 1%; white-space: nowrap">Operating System</th>
    <td>macOS</td>
  </tr><tr>
    <th style="white-space: nowrap">CPU Information</th>
    <td style="white-space: nowrap">Apple M4 Pro</td>
  </tr><tr>
    <th style="white-space: nowrap">Number of Available Cores</th>
    <td style="white-space: nowrap">12</td>
  </tr><tr>
    <th style="white-space: nowrap">Available Memory</th>
    <td style="white-space: nowrap">24 GB</td>
  </tr><tr>
    <th style="white-space: nowrap">Elixir Version</th>
    <td style="white-space: nowrap">1.19.1</td>
  </tr><tr>
    <th style="white-space: nowrap">Erlang Version</th>
    <td style="white-space: nowrap">28.1.1</td>
  </tr>
</table>

## Configuration

Benchmark suite executing with the following configuration:

<table style="width: 1%">
  <tr>
    <th style="width: 1%">:time</th>
    <td style="white-space: nowrap">10 s</td>
  </tr><tr>
    <th>:parallel</th>
    <td style="white-space: nowrap">10</td>
  </tr><tr>
    <th>:warmup</th>
    <td style="white-space: nowrap">2 s</td>
  </tr>
</table>

## Statistics



Run Time

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Devitation</th>
    <th style="text-align: right">Median</th>
    <th style="text-align: right">99th&nbsp;%</th>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 collect 1mb</td>
    <td style="white-space: nowrap; text-align: right">182.24</td>
    <td style="white-space: nowrap; text-align: right">5.49 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;12.65%</td>
    <td style="white-space: nowrap; text-align: right">5.34 ms</td>
    <td style="white-space: nowrap; text-align: right">7.81 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 stream take 1</td>
    <td style="white-space: nowrap; text-align: right">182.22</td>
    <td style="white-space: nowrap; text-align: right">5.49 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;17.68%</td>
    <td style="white-space: nowrap; text-align: right">5.22 ms</td>
    <td style="white-space: nowrap; text-align: right">9.22 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 stream take 1</td>
    <td style="white-space: nowrap; text-align: right">125.90</td>
    <td style="white-space: nowrap; text-align: right">7.94 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;17.50%</td>
    <td style="white-space: nowrap; text-align: right">8.27 ms</td>
    <td style="white-space: nowrap; text-align: right">10.65 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 collect 1mb</td>
    <td style="white-space: nowrap; text-align: right">124.28</td>
    <td style="white-space: nowrap; text-align: right">8.05 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;13.12%</td>
    <td style="white-space: nowrap; text-align: right">7.69 ms</td>
    <td style="white-space: nowrap; text-align: right">11.01 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">http1 collect 1mb</td>
    <td style="white-space: nowrap;text-align: right">182.24</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 stream take 1</td>
    <td style="white-space: nowrap; text-align: right">182.22</td>
    <td style="white-space: nowrap; text-align: right">1.0x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 stream take 1</td>
    <td style="white-space: nowrap; text-align: right">125.90</td>
    <td style="white-space: nowrap; text-align: right">1.45x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 collect 1mb</td>
    <td style="white-space: nowrap; text-align: right">124.28</td>
    <td style="white-space: nowrap; text-align: right">1.47x</td>
  </tr>

</table>



Memory Usage

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Factor</th>
  </tr>
  <tr>
    <td style="white-space: nowrap">http1 collect 1mb</td>
    <td style="white-space: nowrap">233.82 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 stream take 1</td>
    <td style="white-space: nowrap">2.71 KB</td>
    <td>0.01x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 stream take 1</td>
    <td style="white-space: nowrap">1.20 KB</td>
    <td>0.01x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 collect 1mb</td>
    <td style="white-space: nowrap">0.77 KB</td>
    <td>0.0x</td>
  </tr>
</table>



Reduction Count

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Factor</th>
  </tr>
  <tr>
    <td style="white-space: nowrap">http1 collect 1mb</td>
    <td style="white-space: nowrap">18096.03</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 stream take 1</td>
    <td style="white-space: nowrap">317.00</td>
    <td>0.02x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 stream take 1</td>
    <td style="white-space: nowrap">61.00</td>
    <td>0.0x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 collect 1mb</td>
    <td style="white-space: nowrap">33.00</td>
    <td>0.0x</td>
  </tr>
</table>