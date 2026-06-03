Benchmark

Benchmark run from 2026-06-03 12:15:34.245268Z UTC

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
    <td style="white-space: nowrap">finch http1</td>
    <td style="white-space: nowrap; text-align: right">903.39</td>
    <td style="white-space: nowrap; text-align: right">1.11 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;34.38%</td>
    <td style="white-space: nowrap; text-align: right">1.07 ms</td>
    <td style="white-space: nowrap; text-align: right">1.94 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http1</td>
    <td style="white-space: nowrap; text-align: right">873.20</td>
    <td style="white-space: nowrap; text-align: right">1.15 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;25.79%</td>
    <td style="white-space: nowrap; text-align: right">1.12 ms</td>
    <td style="white-space: nowrap; text-align: right">1.95 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap; text-align: right">742.93</td>
    <td style="white-space: nowrap; text-align: right">1.35 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;22.36%</td>
    <td style="white-space: nowrap; text-align: right">1.31 ms</td>
    <td style="white-space: nowrap; text-align: right">2.18 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">583.93</td>
    <td style="white-space: nowrap; text-align: right">1.71 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;9.41%</td>
    <td style="white-space: nowrap; text-align: right">1.70 ms</td>
    <td style="white-space: nowrap; text-align: right">2.17 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">finch http1</td>
    <td style="white-space: nowrap;text-align: right">903.39</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http1</td>
    <td style="white-space: nowrap; text-align: right">873.20</td>
    <td style="white-space: nowrap; text-align: right">1.03x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap; text-align: right">742.93</td>
    <td style="white-space: nowrap; text-align: right">1.22x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">583.93</td>
    <td style="white-space: nowrap; text-align: right">1.55x</td>
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
    <td style="white-space: nowrap">finch http1</td>
    <td style="white-space: nowrap">13.10 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http1</td>
    <td style="white-space: nowrap">18.47 KB</td>
    <td>1.41x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap">6.78 KB</td>
    <td>0.52x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">0.74 KB</td>
    <td>0.06x</td>
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
    <td style="white-space: nowrap">finch http1</td>
    <td style="white-space: nowrap">1.93 K</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http1</td>
    <td style="white-space: nowrap">2.39 K</td>
    <td>1.24x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap">0.81 K</td>
    <td>0.42x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">0.0250 K</td>
    <td>0.01x</td>
  </tr>
</table>