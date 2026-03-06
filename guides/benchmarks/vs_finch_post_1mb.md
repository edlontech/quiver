Benchmark

Benchmark run from 2026-03-06 20:41:17.138909Z UTC

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
    <td style="white-space: nowrap">quiver http1</td>
    <td style="white-space: nowrap; text-align: right">762.76</td>
    <td style="white-space: nowrap; text-align: right">1.31 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;9.04%</td>
    <td style="white-space: nowrap; text-align: right">1.30 ms</td>
    <td style="white-space: nowrap; text-align: right">1.69 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http1</td>
    <td style="white-space: nowrap; text-align: right">744.70</td>
    <td style="white-space: nowrap; text-align: right">1.34 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;11.30%</td>
    <td style="white-space: nowrap; text-align: right">1.32 ms</td>
    <td style="white-space: nowrap; text-align: right">1.85 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">106.28</td>
    <td style="white-space: nowrap; text-align: right">9.41 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;4.00%</td>
    <td style="white-space: nowrap; text-align: right">9.38 ms</td>
    <td style="white-space: nowrap; text-align: right">10.66 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap; text-align: right">95.50</td>
    <td style="white-space: nowrap; text-align: right">10.47 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;56.53%</td>
    <td style="white-space: nowrap; text-align: right">8.88 ms</td>
    <td style="white-space: nowrap; text-align: right">30.25 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">quiver http1</td>
    <td style="white-space: nowrap;text-align: right">762.76</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http1</td>
    <td style="white-space: nowrap; text-align: right">744.70</td>
    <td style="white-space: nowrap; text-align: right">1.02x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">106.28</td>
    <td style="white-space: nowrap; text-align: right">7.18x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap; text-align: right">95.50</td>
    <td style="white-space: nowrap; text-align: right">7.99x</td>
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
    <td style="white-space: nowrap">quiver http1</td>
    <td style="white-space: nowrap">8.89 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">finch http1</td>
    <td style="white-space: nowrap">13.65 KB</td>
    <td>1.54x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">0.74 KB</td>
    <td>0.08x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap">5.04 KB</td>
    <td>0.57x</td>
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
    <td style="white-space: nowrap">quiver http1</td>
    <td style="white-space: nowrap">878.86</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">finch http1</td>
    <td style="white-space: nowrap">1172.52</td>
    <td>1.33x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">25</td>
    <td>0.03x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap">317.82</td>
    <td>0.36x</td>
  </tr>
</table>