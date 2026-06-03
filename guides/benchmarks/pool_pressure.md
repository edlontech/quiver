Benchmark

Benchmark run from 2026-06-03 12:09:07.171692Z UTC

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
    <td style="white-space: nowrap">15 s</td>
  </tr><tr>
    <th>:parallel</th>
    <td style="white-space: nowrap">20</td>
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
    <td style="white-space: nowrap">http2 (max_connections: 5)</td>
    <td style="white-space: nowrap; text-align: right">90.83</td>
    <td style="white-space: nowrap; text-align: right">11.01 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;1.48%</td>
    <td style="white-space: nowrap; text-align: right">11.00 ms</td>
    <td style="white-space: nowrap; text-align: right">11.48 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 (max_connections: 1)</td>
    <td style="white-space: nowrap; text-align: right">90.64</td>
    <td style="white-space: nowrap; text-align: right">11.03 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;2.55%</td>
    <td style="white-space: nowrap; text-align: right">11.00 ms</td>
    <td style="white-space: nowrap; text-align: right">11.93 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 (size: 2)</td>
    <td style="white-space: nowrap; text-align: right">9.09</td>
    <td style="white-space: nowrap; text-align: right">110.06 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;0.26%</td>
    <td style="white-space: nowrap; text-align: right">110.00 ms</td>
    <td style="white-space: nowrap; text-align: right">111.14 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">http2 (max_connections: 5)</td>
    <td style="white-space: nowrap;text-align: right">90.83</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 (max_connections: 1)</td>
    <td style="white-space: nowrap; text-align: right">90.64</td>
    <td style="white-space: nowrap; text-align: right">1.0x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 (size: 2)</td>
    <td style="white-space: nowrap; text-align: right">9.09</td>
    <td style="white-space: nowrap; text-align: right">10.0x</td>
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
    <td style="white-space: nowrap">http2 (max_connections: 5)</td>
    <td style="white-space: nowrap">742.33 B</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 (max_connections: 1)</td>
    <td style="white-space: nowrap">740.92 B</td>
    <td>1.0x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 (size: 2)</td>
    <td style="white-space: nowrap">8120 B</td>
    <td>10.94x</td>
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
    <td style="white-space: nowrap">http2 (max_connections: 5)</td>
    <td style="white-space: nowrap">25</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 (max_connections: 1)</td>
    <td style="white-space: nowrap">25</td>
    <td>1.0x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 (size: 2)</td>
    <td style="white-space: nowrap">828</td>
    <td>33.12x</td>
  </tr>
</table>