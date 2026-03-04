Benchmark

Benchmark run from 2026-03-04 10:46:53.005318Z UTC

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
    <td style="white-space: nowrap; text-align: right">90.16</td>
    <td style="white-space: nowrap; text-align: right">11.09 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;8.06%</td>
    <td style="white-space: nowrap; text-align: right">11.01 ms</td>
    <td style="white-space: nowrap; text-align: right">12.39 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 (max_connections: 1)</td>
    <td style="white-space: nowrap; text-align: right">88.39</td>
    <td style="white-space: nowrap; text-align: right">11.31 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;5.78%</td>
    <td style="white-space: nowrap; text-align: right">11.06 ms</td>
    <td style="white-space: nowrap; text-align: right">13.76 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 (size: 2)</td>
    <td style="white-space: nowrap; text-align: right">8.97</td>
    <td style="white-space: nowrap; text-align: right">111.52 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;5.08%</td>
    <td style="white-space: nowrap; text-align: right">110.20 ms</td>
    <td style="white-space: nowrap; text-align: right">125.11 ms</td>
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
    <td style="white-space: nowrap;text-align: right">90.16</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 (max_connections: 1)</td>
    <td style="white-space: nowrap; text-align: right">88.39</td>
    <td style="white-space: nowrap; text-align: right">1.02x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 (size: 2)</td>
    <td style="white-space: nowrap; text-align: right">8.97</td>
    <td style="white-space: nowrap; text-align: right">10.05x</td>
  </tr>

</table>