Benchmark

Benchmark run from 2026-03-07 17:27:27.744752Z UTC

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
    <td style="white-space: nowrap; text-align: right">3.74 K</td>
    <td style="white-space: nowrap; text-align: right">267.46 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;23.59%</td>
    <td style="white-space: nowrap; text-align: right">261.71 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">441.58 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+quiver http1</td>
    <td style="white-space: nowrap; text-align: right">3.69 K</td>
    <td style="white-space: nowrap; text-align: right">270.73 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;23.94%</td>
    <td style="white-space: nowrap; text-align: right">265.54 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">427.96 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+finch http1</td>
    <td style="white-space: nowrap; text-align: right">2.98 K</td>
    <td style="white-space: nowrap; text-align: right">335.36 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;27.00%</td>
    <td style="white-space: nowrap; text-align: right">325.21 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">598.21 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">2.40 K</td>
    <td style="white-space: nowrap; text-align: right">416.78 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;22.78%</td>
    <td style="white-space: nowrap; text-align: right">407.33 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">681.54 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+quiver http2</td>
    <td style="white-space: nowrap; text-align: right">2.37 K</td>
    <td style="white-space: nowrap; text-align: right">421.33 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;18.02%</td>
    <td style="white-space: nowrap; text-align: right">416.15 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">621.04 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+finch http2</td>
    <td style="white-space: nowrap; text-align: right">1.90 K</td>
    <td style="white-space: nowrap; text-align: right">526.29 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;27.49%</td>
    <td style="white-space: nowrap; text-align: right">501.63 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">967.32 &micro;s</td>
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
    <td style="white-space: nowrap;text-align: right">3.74 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+quiver http1</td>
    <td style="white-space: nowrap; text-align: right">3.69 K</td>
    <td style="white-space: nowrap; text-align: right">1.01x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+finch http1</td>
    <td style="white-space: nowrap; text-align: right">2.98 K</td>
    <td style="white-space: nowrap; text-align: right">1.25x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">2.40 K</td>
    <td style="white-space: nowrap; text-align: right">1.56x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+quiver http2</td>
    <td style="white-space: nowrap; text-align: right">2.37 K</td>
    <td style="white-space: nowrap; text-align: right">1.58x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+finch http2</td>
    <td style="white-space: nowrap; text-align: right">1.90 K</td>
    <td style="white-space: nowrap; text-align: right">1.97x</td>
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
    <td style="white-space: nowrap">7.88 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+quiver http1</td>
    <td style="white-space: nowrap">12.27 KB</td>
    <td>1.56x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+finch http1</td>
    <td style="white-space: nowrap">13.82 KB</td>
    <td>1.75x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">0.77 KB</td>
    <td>0.1x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+quiver http2</td>
    <td style="white-space: nowrap">4.69 KB</td>
    <td>0.6x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+finch http2</td>
    <td style="white-space: nowrap">5.94 KB</td>
    <td>0.75x</td>
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
    <td style="white-space: nowrap">827.36</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+quiver http1</td>
    <td style="white-space: nowrap">1153.37</td>
    <td>1.39x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+finch http1</td>
    <td style="white-space: nowrap">1150.50</td>
    <td>1.39x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">25.00</td>
    <td>0.03x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+quiver http2</td>
    <td style="white-space: nowrap">350.00</td>
    <td>0.42x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+finch http2</td>
    <td style="white-space: nowrap">430.94</td>
    <td>0.52x</td>
  </tr>
</table>