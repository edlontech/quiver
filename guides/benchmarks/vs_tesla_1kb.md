Benchmark

Benchmark run from 2026-06-03 12:21:28.920914Z UTC

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
    <td style="white-space: nowrap; text-align: right">3.77 K</td>
    <td style="white-space: nowrap; text-align: right">265.56 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;22.49%</td>
    <td style="white-space: nowrap; text-align: right">260.75 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">427.46 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+quiver http1</td>
    <td style="white-space: nowrap; text-align: right">3.72 K</td>
    <td style="white-space: nowrap; text-align: right">269.17 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;27.59%</td>
    <td style="white-space: nowrap; text-align: right">262.63 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">443.90 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+finch http1</td>
    <td style="white-space: nowrap; text-align: right">2.99 K</td>
    <td style="white-space: nowrap; text-align: right">334.67 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;18.27%</td>
    <td style="white-space: nowrap; text-align: right">328.79 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">500.75 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">2.50 K</td>
    <td style="white-space: nowrap; text-align: right">399.39 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;22.87%</td>
    <td style="white-space: nowrap; text-align: right">390.42 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">664.85 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+quiver http2</td>
    <td style="white-space: nowrap; text-align: right">2.32 K</td>
    <td style="white-space: nowrap; text-align: right">431.92 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;26.80%</td>
    <td style="white-space: nowrap; text-align: right">419.00 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">740.11 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+finch http2</td>
    <td style="white-space: nowrap; text-align: right">0.0617 K</td>
    <td style="white-space: nowrap; text-align: right">16219.83 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;28.30%</td>
    <td style="white-space: nowrap; text-align: right">15654.90 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">29577.56 &micro;s</td>
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
    <td style="white-space: nowrap;text-align: right">3.77 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+quiver http1</td>
    <td style="white-space: nowrap; text-align: right">3.72 K</td>
    <td style="white-space: nowrap; text-align: right">1.01x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+finch http1</td>
    <td style="white-space: nowrap; text-align: right">2.99 K</td>
    <td style="white-space: nowrap; text-align: right">1.26x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">2.50 K</td>
    <td style="white-space: nowrap; text-align: right">1.5x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+quiver http2</td>
    <td style="white-space: nowrap; text-align: right">2.32 K</td>
    <td style="white-space: nowrap; text-align: right">1.63x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">tesla+finch http2</td>
    <td style="white-space: nowrap; text-align: right">0.0617 K</td>
    <td style="white-space: nowrap; text-align: right">61.08x</td>
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
    <td style="white-space: nowrap">12.38 KB</td>
    <td>1.57x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+finch http1</td>
    <td style="white-space: nowrap">13.65 KB</td>
    <td>1.73x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">0.77 KB</td>
    <td>0.1x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+quiver http2</td>
    <td style="white-space: nowrap">4.80 KB</td>
    <td>0.61x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+finch http2</td>
    <td style="white-space: nowrap">227.90 KB</td>
    <td>28.94x</td>
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
    <td style="white-space: nowrap">0.83 K</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+quiver http1</td>
    <td style="white-space: nowrap">1.17 K</td>
    <td>1.41x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+finch http1</td>
    <td style="white-space: nowrap">1.18 K</td>
    <td>1.43x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">0.0250 K</td>
    <td>0.03x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+quiver http2</td>
    <td style="white-space: nowrap">0.36 K</td>
    <td>0.44x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">tesla+finch http2</td>
    <td style="white-space: nowrap">33.32 K</td>
    <td>40.28x</td>
  </tr>
</table>