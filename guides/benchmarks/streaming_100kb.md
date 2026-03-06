Benchmark

Benchmark run from 2026-03-06 20:32:39.817668Z UTC

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
    <td style="white-space: nowrap; text-align: right">1.23 K</td>
    <td style="white-space: nowrap; text-align: right">0.81 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;25.10%</td>
    <td style="white-space: nowrap; text-align: right">0.77 ms</td>
    <td style="white-space: nowrap; text-align: right">1.33 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 collected</td>
    <td style="white-space: nowrap; text-align: right">1.22 K</td>
    <td style="white-space: nowrap; text-align: right">0.82 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;26.77%</td>
    <td style="white-space: nowrap; text-align: right">0.78 ms</td>
    <td style="white-space: nowrap; text-align: right">1.37 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 collected</td>
    <td style="white-space: nowrap; text-align: right">0.88 K</td>
    <td style="white-space: nowrap; text-align: right">1.13 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;11.18%</td>
    <td style="white-space: nowrap; text-align: right">1.12 ms</td>
    <td style="white-space: nowrap; text-align: right">1.47 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 stream</td>
    <td style="white-space: nowrap; text-align: right">0.85 K</td>
    <td style="white-space: nowrap; text-align: right">1.17 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;10.94%</td>
    <td style="white-space: nowrap; text-align: right">1.16 ms</td>
    <td style="white-space: nowrap; text-align: right">1.51 ms</td>
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
    <td style="white-space: nowrap;text-align: right">1.23 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 collected</td>
    <td style="white-space: nowrap; text-align: right">1.22 K</td>
    <td style="white-space: nowrap; text-align: right">1.01x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 collected</td>
    <td style="white-space: nowrap; text-align: right">0.88 K</td>
    <td style="white-space: nowrap; text-align: right">1.4x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 stream</td>
    <td style="white-space: nowrap; text-align: right">0.85 K</td>
    <td style="white-space: nowrap; text-align: right">1.45x</td>
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
    <td style="white-space: nowrap">11.91 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 collected</td>
    <td style="white-space: nowrap">18.65 KB</td>
    <td>1.57x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 collected</td>
    <td style="white-space: nowrap">0.74 KB</td>
    <td>0.06x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 stream</td>
    <td style="white-space: nowrap">2.75 KB</td>
    <td>0.23x</td>
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
    <td style="white-space: nowrap">1.19 K</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 collected</td>
    <td style="white-space: nowrap">2.35 K</td>
    <td>1.97x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 collected</td>
    <td style="white-space: nowrap">0.0260 K</td>
    <td>0.02x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 stream</td>
    <td style="white-space: nowrap">0.181 K</td>
    <td>0.15x</td>
  </tr>
</table>