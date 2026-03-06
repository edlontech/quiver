Benchmark

Benchmark run from 2026-03-06 20:30:30.250306Z UTC

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
    <td style="white-space: nowrap; text-align: right">90.75</td>
    <td style="white-space: nowrap; text-align: right">11.02 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;1.68%</td>
    <td style="white-space: nowrap; text-align: right">11.00 ms</td>
    <td style="white-space: nowrap; text-align: right">11.72 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 (max_connections: 1)</td>
    <td style="white-space: nowrap; text-align: right">88.40</td>
    <td style="white-space: nowrap; text-align: right">11.31 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;6.12%</td>
    <td style="white-space: nowrap; text-align: right">11.05 ms</td>
    <td style="white-space: nowrap; text-align: right">13.64 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 (size: 2)</td>
    <td style="white-space: nowrap; text-align: right">9.07</td>
    <td style="white-space: nowrap; text-align: right">110.31 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;0.85%</td>
    <td style="white-space: nowrap; text-align: right">110.02 ms</td>
    <td style="white-space: nowrap; text-align: right">115.14 ms</td>
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
    <td style="white-space: nowrap;text-align: right">90.75</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 (max_connections: 1)</td>
    <td style="white-space: nowrap; text-align: right">88.40</td>
    <td style="white-space: nowrap; text-align: right">1.03x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 (size: 2)</td>
    <td style="white-space: nowrap; text-align: right">9.07</td>
    <td style="white-space: nowrap; text-align: right">10.01x</td>
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
    <td style="white-space: nowrap">716.85 B</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 (max_connections: 1)</td>
    <td style="white-space: nowrap">713.39 B</td>
    <td>1.0x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 (size: 2)</td>
    <td style="white-space: nowrap">8176 B</td>
    <td>11.41x</td>
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
    <td style="white-space: nowrap">817.91</td>
    <td>32.72x</td>
  </tr>
</table>