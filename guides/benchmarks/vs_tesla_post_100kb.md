Benchmark

Benchmark run from 2026-03-07 17:33:57.216419Z UTC

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
    <td style="white-space: nowrap; text-align: right">3.07 K</td>
    <td style="white-space: nowrap; text-align: right">0.33 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;25.97%</td>
    <td style="white-space: nowrap; text-align: right">0.32 ms</td>
    <td style="white-space: nowrap; text-align: right">0.52 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+quiver http1</td>
    <td style="white-space: nowrap; text-align: right">2.97 K</td>
    <td style="white-space: nowrap; text-align: right">0.34 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;20.08%</td>
    <td style="white-space: nowrap; text-align: right">0.33 ms</td>
    <td style="white-space: nowrap; text-align: right">0.52 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+finch http1</td>
    <td style="white-space: nowrap; text-align: right">2.66 K</td>
    <td style="white-space: nowrap; text-align: right">0.38 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;21.48%</td>
    <td style="white-space: nowrap; text-align: right">0.37 ms</td>
    <td style="white-space: nowrap; text-align: right">0.60 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+quiver http2</td>
    <td style="white-space: nowrap; text-align: right">0.79 K</td>
    <td style="white-space: nowrap; text-align: right">1.27 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;7.95%</td>
    <td style="white-space: nowrap; text-align: right">1.26 ms</td>
    <td style="white-space: nowrap; text-align: right">1.51 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">0.78 K</td>
    <td style="white-space: nowrap; text-align: right">1.29 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;20.42%</td>
    <td style="white-space: nowrap; text-align: right">1.27 ms</td>
    <td style="white-space: nowrap; text-align: right">1.69 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+finch http2</td>
    <td style="white-space: nowrap; text-align: right">0.62 K</td>
    <td style="white-space: nowrap; text-align: right">1.60 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;41.80%</td>
    <td style="white-space: nowrap; text-align: right">1.42 ms</td>
    <td style="white-space: nowrap; text-align: right">3.83 ms</td>
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
    <td style="white-space: nowrap;text-align: right">3.07 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+quiver http1</td>
    <td style="white-space: nowrap; text-align: right">2.97 K</td>
    <td style="white-space: nowrap; text-align: right">1.03x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+finch http1</td>
    <td style="white-space: nowrap; text-align: right">2.66 K</td>
    <td style="white-space: nowrap; text-align: right">1.15x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+quiver http2</td>
    <td style="white-space: nowrap; text-align: right">0.79 K</td>
    <td style="white-space: nowrap; text-align: right">3.88x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">0.78 K</td>
    <td style="white-space: nowrap; text-align: right">3.94x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+finch http2</td>
    <td style="white-space: nowrap; text-align: right">0.62 K</td>
    <td style="white-space: nowrap; text-align: right">4.92x</td>
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
    <td style="white-space: nowrap">8.80 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+quiver http1</td>
    <td style="white-space: nowrap">13.02 KB</td>
    <td>1.48x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+finch http1</td>
    <td style="white-space: nowrap">14.93 KB</td>
    <td>1.7x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+quiver http2</td>
    <td style="white-space: nowrap">5.11 KB</td>
    <td>0.58x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">0.76 KB</td>
    <td>0.09x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+finch http2</td>
    <td style="white-space: nowrap">6.31 KB</td>
    <td>0.72x</td>
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
    <td style="white-space: nowrap">887.27</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+quiver http1</td>
    <td style="white-space: nowrap">1218.36</td>
    <td>1.37x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+finch http1</td>
    <td style="white-space: nowrap">1293.61</td>
    <td>1.46x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+quiver http2</td>
    <td style="white-space: nowrap">371.00</td>
    <td>0.42x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">25.00</td>
    <td>0.03x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+finch http2</td>
    <td style="white-space: nowrap">437.16</td>
    <td>0.49x</td>
  </tr>
</table>