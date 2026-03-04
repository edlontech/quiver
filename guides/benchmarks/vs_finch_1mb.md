Benchmark

Benchmark run from 2026-03-04 10:52:34.459310Z UTC

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
    <td style="white-space: nowrap; text-align: right">83.50</td>
    <td style="white-space: nowrap; text-align: right">11.98 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;34.89%</td>
    <td style="white-space: nowrap; text-align: right">11.35 ms</td>
    <td style="white-space: nowrap; text-align: right">25.85 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http1</td>
    <td style="white-space: nowrap; text-align: right">68.32</td>
    <td style="white-space: nowrap; text-align: right">14.64 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;52.95%</td>
    <td style="white-space: nowrap; text-align: right">12.96 ms</td>
    <td style="white-space: nowrap; text-align: right">47.09 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">42.56</td>
    <td style="white-space: nowrap; text-align: right">23.50 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;14.20%</td>
    <td style="white-space: nowrap; text-align: right">22.71 ms</td>
    <td style="white-space: nowrap; text-align: right">37.06 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap; text-align: right">7.85</td>
    <td style="white-space: nowrap; text-align: right">127.41 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;286.01%</td>
    <td style="white-space: nowrap; text-align: right">7.26 ms</td>
    <td style="white-space: nowrap; text-align: right">1396.62 ms</td>
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
    <td style="white-space: nowrap;text-align: right">83.50</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http1</td>
    <td style="white-space: nowrap; text-align: right">68.32</td>
    <td style="white-space: nowrap; text-align: right">1.22x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">42.56</td>
    <td style="white-space: nowrap; text-align: right">1.96x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap; text-align: right">7.85</td>
    <td style="white-space: nowrap; text-align: right">10.64x</td>
  </tr>

</table>