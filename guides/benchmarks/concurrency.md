Benchmark

Benchmark run from 2026-06-03 12:05:54.301425Z UTC

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
    <td style="white-space: nowrap">50</td>
  </tr><tr>
    <th>:warmup</th>
    <td style="white-space: nowrap">3 s</td>
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
    <td style="white-space: nowrap">http1</td>
    <td style="white-space: nowrap; text-align: right">1.54 K</td>
    <td style="white-space: nowrap; text-align: right">650.61 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;29.81%</td>
    <td style="white-space: nowrap; text-align: right">633.71 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">1176.38 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2</td>
    <td style="white-space: nowrap; text-align: right">1.03 K</td>
    <td style="white-space: nowrap; text-align: right">969.20 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;13.67%</td>
    <td style="white-space: nowrap; text-align: right">963.29 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">1317.42 &micro;s</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">http1</td>
    <td style="white-space: nowrap;text-align: right">1.54 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2</td>
    <td style="white-space: nowrap; text-align: right">1.03 K</td>
    <td style="white-space: nowrap; text-align: right">1.49x</td>
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
    <td style="white-space: nowrap">http1</td>
    <td style="white-space: nowrap">7.92 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2</td>
    <td style="white-space: nowrap">0.74 KB</td>
    <td>0.09x</td>
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
    <td style="white-space: nowrap">http1</td>
    <td style="white-space: nowrap">824.06</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2</td>
    <td style="white-space: nowrap">25.00</td>
    <td>0.03x</td>
  </tr>
</table>