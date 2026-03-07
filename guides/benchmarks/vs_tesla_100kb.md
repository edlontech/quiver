Benchmark

Benchmark run from 2026-03-07 17:29:05.057420Z UTC

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
    <td style="white-space: nowrap; text-align: right">826.97</td>
    <td style="white-space: nowrap; text-align: right">1.21 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;24.52%</td>
    <td style="white-space: nowrap; text-align: right">1.18 ms</td>
    <td style="white-space: nowrap; text-align: right">2.00 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+finch http1</td>
    <td style="white-space: nowrap; text-align: right">826.92</td>
    <td style="white-space: nowrap; text-align: right">1.21 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;25.04%</td>
    <td style="white-space: nowrap; text-align: right">1.17 ms</td>
    <td style="white-space: nowrap; text-align: right">2.04 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+quiver http1</td>
    <td style="white-space: nowrap; text-align: right">762.00</td>
    <td style="white-space: nowrap; text-align: right">1.31 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;29.48%</td>
    <td style="white-space: nowrap; text-align: right">1.25 ms</td>
    <td style="white-space: nowrap; text-align: right">2.52 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">564.43</td>
    <td style="white-space: nowrap; text-align: right">1.77 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;10.41%</td>
    <td style="white-space: nowrap; text-align: right">1.75 ms</td>
    <td style="white-space: nowrap; text-align: right">2.24 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+quiver http2</td>
    <td style="white-space: nowrap; text-align: right">542.94</td>
    <td style="white-space: nowrap; text-align: right">1.84 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;19.24%</td>
    <td style="white-space: nowrap; text-align: right">1.80 ms</td>
    <td style="white-space: nowrap; text-align: right">2.84 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+finch http2</td>
    <td style="white-space: nowrap; text-align: right">93.39</td>
    <td style="white-space: nowrap; text-align: right">10.71 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;307.49%</td>
    <td style="white-space: nowrap; text-align: right">0.88 ms</td>
    <td style="white-space: nowrap; text-align: right">158.22 ms</td>
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
    <td style="white-space: nowrap;text-align: right">826.97</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+finch http1</td>
    <td style="white-space: nowrap; text-align: right">826.92</td>
    <td style="white-space: nowrap; text-align: right">1.0x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+quiver http1</td>
    <td style="white-space: nowrap; text-align: right">762.00</td>
    <td style="white-space: nowrap; text-align: right">1.09x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">564.43</td>
    <td style="white-space: nowrap; text-align: right">1.47x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+quiver http2</td>
    <td style="white-space: nowrap; text-align: right">542.94</td>
    <td style="white-space: nowrap; text-align: right">1.52x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+finch http2</td>
    <td style="white-space: nowrap; text-align: right">93.39</td>
    <td style="white-space: nowrap; text-align: right">8.85x</td>
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
    <td style="white-space: nowrap">18.47 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+finch http1</td>
    <td style="white-space: nowrap">13.86 KB</td>
    <td>0.75x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+quiver http1</td>
    <td style="white-space: nowrap">22.82 KB</td>
    <td>1.24x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">0.74 KB</td>
    <td>0.04x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+quiver http2</td>
    <td style="white-space: nowrap">4.67 KB</td>
    <td>0.25x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+finch http2</td>
    <td style="white-space: nowrap">13.39 KB</td>
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
    <td style="white-space: nowrap">2.39 K</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+finch http1</td>
    <td style="white-space: nowrap">1.96 K</td>
    <td>0.82x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+quiver http1</td>
    <td style="white-space: nowrap">2.72 K</td>
    <td>1.14x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">0.0250 K</td>
    <td>0.01x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+quiver http2</td>
    <td style="white-space: nowrap">0.35 K</td>
    <td>0.15x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+finch http2</td>
    <td style="white-space: nowrap">1.12 K</td>
    <td>0.47x</td>
  </tr>
</table>