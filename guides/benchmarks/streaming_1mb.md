Benchmark

Benchmark run from 2026-03-06 20:33:43.987021Z UTC

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
    <td style="white-space: nowrap">http1 stream</td>
    <td style="white-space: nowrap; text-align: right">168.05</td>
    <td style="white-space: nowrap; text-align: right">5.95 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;14.63%</td>
    <td style="white-space: nowrap; text-align: right">5.78 ms</td>
    <td style="white-space: nowrap; text-align: right">8.71 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 collected</td>
    <td style="white-space: nowrap; text-align: right">163.16</td>
    <td style="white-space: nowrap; text-align: right">6.13 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;13.89%</td>
    <td style="white-space: nowrap; text-align: right">5.97 ms</td>
    <td style="white-space: nowrap; text-align: right">8.88 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 collected</td>
    <td style="white-space: nowrap; text-align: right">107.91</td>
    <td style="white-space: nowrap; text-align: right">9.27 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;14.54%</td>
    <td style="white-space: nowrap; text-align: right">8.57 ms</td>
    <td style="white-space: nowrap; text-align: right">12.22 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 stream</td>
    <td style="white-space: nowrap; text-align: right">105.58</td>
    <td style="white-space: nowrap; text-align: right">9.47 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;14.64%</td>
    <td style="white-space: nowrap; text-align: right">8.79 ms</td>
    <td style="white-space: nowrap; text-align: right">12.10 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">http1 stream</td>
    <td style="white-space: nowrap;text-align: right">168.05</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 collected</td>
    <td style="white-space: nowrap; text-align: right">163.16</td>
    <td style="white-space: nowrap; text-align: right">1.03x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 collected</td>
    <td style="white-space: nowrap; text-align: right">107.91</td>
    <td style="white-space: nowrap; text-align: right">1.56x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 stream</td>
    <td style="white-space: nowrap; text-align: right">105.58</td>
    <td style="white-space: nowrap; text-align: right">1.59x</td>
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
    <td style="white-space: nowrap">http1 stream</td>
    <td style="white-space: nowrap">106.03 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 collected</td>
    <td style="white-space: nowrap">233.28 KB</td>
    <td>2.2x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 collected</td>
    <td style="white-space: nowrap">0.76 KB</td>
    <td>0.01x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 stream</td>
    <td style="white-space: nowrap">15.68 KB</td>
    <td>0.15x</td>
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
    <td style="white-space: nowrap">http1 stream</td>
    <td style="white-space: nowrap">11.67 K</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 collected</td>
    <td style="white-space: nowrap">17.55 K</td>
    <td>1.5x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 collected</td>
    <td style="white-space: nowrap">0.0330 K</td>
    <td>0.0x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 stream</td>
    <td style="white-space: nowrap">1.36 K</td>
    <td>0.12x</td>
  </tr>
</table>