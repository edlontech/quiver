Benchmark

Benchmark run from 2026-03-06 20:40:12.846938Z UTC

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
    <td style="white-space: nowrap; text-align: right">3.05 K</td>
    <td style="white-space: nowrap; text-align: right">0.33 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;21.50%</td>
    <td style="white-space: nowrap; text-align: right">0.32 ms</td>
    <td style="white-space: nowrap; text-align: right">0.51 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http1</td>
    <td style="white-space: nowrap; text-align: right">2.61 K</td>
    <td style="white-space: nowrap; text-align: right">0.38 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;22.17%</td>
    <td style="white-space: nowrap; text-align: right">0.38 ms</td>
    <td style="white-space: nowrap; text-align: right">0.62 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">0.79 K</td>
    <td style="white-space: nowrap; text-align: right">1.26 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;8.23%</td>
    <td style="white-space: nowrap; text-align: right">1.26 ms</td>
    <td style="white-space: nowrap; text-align: right">1.52 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap; text-align: right">0.62 K</td>
    <td style="white-space: nowrap; text-align: right">1.61 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;41.60%</td>
    <td style="white-space: nowrap; text-align: right">1.43 ms</td>
    <td style="white-space: nowrap; text-align: right">3.80 ms</td>
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
    <td style="white-space: nowrap;text-align: right">3.05 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http1</td>
    <td style="white-space: nowrap; text-align: right">2.61 K</td>
    <td style="white-space: nowrap; text-align: right">1.17x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">0.79 K</td>
    <td style="white-space: nowrap; text-align: right">3.84x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap; text-align: right">0.62 K</td>
    <td style="white-space: nowrap; text-align: right">4.9x</td>
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
    <td style="white-space: nowrap">0.75 KB</td>
    <td>0.08x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap">5.06 KB</td>
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
    <td style="white-space: nowrap">866.26</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">finch http1</td>
    <td style="white-space: nowrap">1177.37</td>
    <td>1.36x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">25.00</td>
    <td>0.03x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap">320.27</td>
    <td>0.37x</td>
  </tr>
</table>