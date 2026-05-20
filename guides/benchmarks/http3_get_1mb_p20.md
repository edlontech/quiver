Benchmark

Benchmark run from 2026-05-20 15:47:08.025988Z UTC

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
    <td style="white-space: nowrap">2 s</td>
  </tr><tr>
    <th>:parallel</th>
    <td style="white-space: nowrap">20</td>
  </tr><tr>
    <th>:warmup</th>
    <td style="white-space: nowrap">1 s</td>
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
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">54.48</td>
    <td style="white-space: nowrap; text-align: right">18.36 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;9.91%</td>
    <td style="white-space: nowrap; text-align: right">19.20 ms</td>
    <td style="white-space: nowrap; text-align: right">20.93 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http3</td>
    <td style="white-space: nowrap; text-align: right">2.17</td>
    <td style="white-space: nowrap; text-align: right">460.54 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;28.95%</td>
    <td style="white-space: nowrap; text-align: right">549.48 ms</td>
    <td style="white-space: nowrap; text-align: right">723.63 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap;text-align: right">54.48</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http3</td>
    <td style="white-space: nowrap; text-align: right">2.17</td>
    <td style="white-space: nowrap; text-align: right">25.09x</td>
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
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">789.66 B</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http3</td>
    <td style="white-space: nowrap">488 B</td>
    <td>0.62x</td>
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
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">32.99</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http3</td>
    <td style="white-space: nowrap">30</td>
    <td>0.91x</td>
  </tr>
</table>