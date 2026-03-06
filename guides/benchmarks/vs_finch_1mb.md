Benchmark

Benchmark run from 2026-03-06 20:38:03.882769Z UTC

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
    <td style="white-space: nowrap; text-align: right">95.98</td>
    <td style="white-space: nowrap; text-align: right">10.42 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;24.25%</td>
    <td style="white-space: nowrap; text-align: right">10.20 ms</td>
    <td style="white-space: nowrap; text-align: right">17.20 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http1</td>
    <td style="white-space: nowrap; text-align: right">89.18</td>
    <td style="white-space: nowrap; text-align: right">11.21 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;25.95%</td>
    <td style="white-space: nowrap; text-align: right">10.91 ms</td>
    <td style="white-space: nowrap; text-align: right">19.28 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">60.68</td>
    <td style="white-space: nowrap; text-align: right">16.48 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;8.85%</td>
    <td style="white-space: nowrap; text-align: right">16.23 ms</td>
    <td style="white-space: nowrap; text-align: right">19.25 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap; text-align: right">8.49</td>
    <td style="white-space: nowrap; text-align: right">117.83 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;281.22%</td>
    <td style="white-space: nowrap; text-align: right">7.15 ms</td>
    <td style="white-space: nowrap; text-align: right">1206.65 ms</td>
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
    <td style="white-space: nowrap;text-align: right">95.98</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http1</td>
    <td style="white-space: nowrap; text-align: right">89.18</td>
    <td style="white-space: nowrap; text-align: right">1.08x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">60.68</td>
    <td style="white-space: nowrap; text-align: right">1.58x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap; text-align: right">8.49</td>
    <td style="white-space: nowrap; text-align: right">11.31x</td>
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
    <td style="white-space: nowrap">16.30 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http1</td>
    <td style="white-space: nowrap">232.86 KB</td>
    <td>14.29x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">0.76 KB</td>
    <td>0.05x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap">104.96 KB</td>
    <td>6.44x</td>
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
    <td style="white-space: nowrap">9.53 K</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http1</td>
    <td style="white-space: nowrap">17.58 K</td>
    <td>1.84x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">0.0320 K</td>
    <td>0.0x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap">8.41 K</td>
    <td>0.88x</td>
  </tr>
</table>