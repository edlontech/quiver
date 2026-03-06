Benchmark

Benchmark run from 2026-03-06 20:36:57.568730Z UTC

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
    <td style="white-space: nowrap; text-align: right">841.20</td>
    <td style="white-space: nowrap; text-align: right">1.19 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;24.38%</td>
    <td style="white-space: nowrap; text-align: right">1.16 ms</td>
    <td style="white-space: nowrap; text-align: right">1.97 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http1</td>
    <td style="white-space: nowrap; text-align: right">815.21</td>
    <td style="white-space: nowrap; text-align: right">1.23 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;26.05%</td>
    <td style="white-space: nowrap; text-align: right">1.19 ms</td>
    <td style="white-space: nowrap; text-align: right">2.12 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">570.11</td>
    <td style="white-space: nowrap; text-align: right">1.75 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;11.05%</td>
    <td style="white-space: nowrap; text-align: right">1.73 ms</td>
    <td style="white-space: nowrap; text-align: right">2.27 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap; text-align: right">90.82</td>
    <td style="white-space: nowrap; text-align: right">11.01 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;300.18%</td>
    <td style="white-space: nowrap; text-align: right">0.88 ms</td>
    <td style="white-space: nowrap; text-align: right">158.47 ms</td>
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
    <td style="white-space: nowrap;text-align: right">841.20</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http1</td>
    <td style="white-space: nowrap; text-align: right">815.21</td>
    <td style="white-space: nowrap; text-align: right">1.03x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">570.11</td>
    <td style="white-space: nowrap; text-align: right">1.48x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap; text-align: right">90.82</td>
    <td style="white-space: nowrap; text-align: right">9.26x</td>
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
    <td style="white-space: nowrap">12.87 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http1</td>
    <td style="white-space: nowrap">18.65 KB</td>
    <td>1.45x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">0.74 KB</td>
    <td>0.06x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap">12.49 KB</td>
    <td>0.97x</td>
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
    <td style="white-space: nowrap">1.84 K</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http1</td>
    <td style="white-space: nowrap">2.35 K</td>
    <td>1.28x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">0.0250 K</td>
    <td>0.01x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap">1.05 K</td>
    <td>0.57x</td>
  </tr>
</table>