Benchmark

Benchmark run from 2026-06-03 12:16:38.501739Z UTC

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
    <td style="white-space: nowrap; text-align: right">107.33</td>
    <td style="white-space: nowrap; text-align: right">9.32 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;22.58%</td>
    <td style="white-space: nowrap; text-align: right">9.14 ms</td>
    <td style="white-space: nowrap; text-align: right">14.93 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http1</td>
    <td style="white-space: nowrap; text-align: right">100.54</td>
    <td style="white-space: nowrap; text-align: right">9.95 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;23.84%</td>
    <td style="white-space: nowrap; text-align: right">9.71 ms</td>
    <td style="white-space: nowrap; text-align: right">16.55 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap; text-align: right">89.58</td>
    <td style="white-space: nowrap; text-align: right">11.16 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;20.36%</td>
    <td style="white-space: nowrap; text-align: right">10.94 ms</td>
    <td style="white-space: nowrap; text-align: right">17.42 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">68.52</td>
    <td style="white-space: nowrap; text-align: right">14.59 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;6.68%</td>
    <td style="white-space: nowrap; text-align: right">14.48 ms</td>
    <td style="white-space: nowrap; text-align: right">16.24 ms</td>
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
    <td style="white-space: nowrap;text-align: right">107.33</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http1</td>
    <td style="white-space: nowrap; text-align: right">100.54</td>
    <td style="white-space: nowrap; text-align: right">1.07x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap; text-align: right">89.58</td>
    <td style="white-space: nowrap; text-align: right">1.2x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">68.52</td>
    <td style="white-space: nowrap; text-align: right">1.57x</td>
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
    <td style="white-space: nowrap">16.80 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http1</td>
    <td style="white-space: nowrap">233.87 KB</td>
    <td>13.92x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap">15.21 KB</td>
    <td>0.91x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">0.77 KB</td>
    <td>0.05x</td>
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
    <td style="white-space: nowrap">9.66 K</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http1</td>
    <td style="white-space: nowrap">18.10 K</td>
    <td>1.87x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap">4.88 K</td>
    <td>0.5x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">0.0320 K</td>
    <td>0.0x</td>
  </tr>
</table>