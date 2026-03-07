Benchmark

Benchmark run from 2026-03-07 17:30:43.777529Z UTC

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
    <td style="white-space: nowrap">tesla+finch http1</td>
    <td style="white-space: nowrap; text-align: right">93.92</td>
    <td style="white-space: nowrap; text-align: right">10.65 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;23.30%</td>
    <td style="white-space: nowrap; text-align: right">10.44 ms</td>
    <td style="white-space: nowrap; text-align: right">17.16 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http1</td>
    <td style="white-space: nowrap; text-align: right">92.43</td>
    <td style="white-space: nowrap; text-align: right">10.82 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;25.41%</td>
    <td style="white-space: nowrap; text-align: right">10.53 ms</td>
    <td style="white-space: nowrap; text-align: right">18.54 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+quiver http1</td>
    <td style="white-space: nowrap; text-align: right">90.41</td>
    <td style="white-space: nowrap; text-align: right">11.06 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;25.54%</td>
    <td style="white-space: nowrap; text-align: right">10.74 ms</td>
    <td style="white-space: nowrap; text-align: right">19.12 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">61.43</td>
    <td style="white-space: nowrap; text-align: right">16.28 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;3.16%</td>
    <td style="white-space: nowrap; text-align: right">16.26 ms</td>
    <td style="white-space: nowrap; text-align: right">17.61 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+quiver http2</td>
    <td style="white-space: nowrap; text-align: right">61.09</td>
    <td style="white-space: nowrap; text-align: right">16.37 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;3.95%</td>
    <td style="white-space: nowrap; text-align: right">16.31 ms</td>
    <td style="white-space: nowrap; text-align: right">18.35 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+finch http2</td>
    <td style="white-space: nowrap; text-align: right">8.52</td>
    <td style="white-space: nowrap; text-align: right">117.41 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;282.04%</td>
    <td style="white-space: nowrap; text-align: right">7.11 ms</td>
    <td style="white-space: nowrap; text-align: right">1199.51 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">tesla+finch http1</td>
    <td style="white-space: nowrap;text-align: right">93.92</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http1</td>
    <td style="white-space: nowrap; text-align: right">92.43</td>
    <td style="white-space: nowrap; text-align: right">1.02x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+quiver http1</td>
    <td style="white-space: nowrap; text-align: right">90.41</td>
    <td style="white-space: nowrap; text-align: right">1.04x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">61.43</td>
    <td style="white-space: nowrap; text-align: right">1.53x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+quiver http2</td>
    <td style="white-space: nowrap; text-align: right">61.09</td>
    <td style="white-space: nowrap; text-align: right">1.54x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+finch http2</td>
    <td style="white-space: nowrap; text-align: right">8.52</td>
    <td style="white-space: nowrap; text-align: right">11.03x</td>
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
    <td style="white-space: nowrap">tesla+finch http1</td>
    <td style="white-space: nowrap">17.10 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http1</td>
    <td style="white-space: nowrap">233.87 KB</td>
    <td>13.68x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+quiver http1</td>
    <td style="white-space: nowrap">236.80 KB</td>
    <td>13.85x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">0.77 KB</td>
    <td>0.05x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+quiver http2</td>
    <td style="white-space: nowrap">4.69 KB</td>
    <td>0.27x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+finch http2</td>
    <td style="white-space: nowrap">96.09 KB</td>
    <td>5.62x</td>
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
    <td style="white-space: nowrap">tesla+finch http1</td>
    <td style="white-space: nowrap">9.66 K</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http1</td>
    <td style="white-space: nowrap">18.10 K</td>
    <td>1.87x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+quiver http1</td>
    <td style="white-space: nowrap">18.57 K</td>
    <td>1.92x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">0.0320 K</td>
    <td>0.0x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+quiver http2</td>
    <td style="white-space: nowrap">0.36 K</td>
    <td>0.04x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+finch http2</td>
    <td style="white-space: nowrap">8.70 K</td>
    <td>0.9x</td>
  </tr>
</table>