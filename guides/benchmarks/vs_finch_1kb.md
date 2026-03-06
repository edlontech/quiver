Benchmark

Benchmark run from 2026-03-06 20:35:52.816565Z UTC

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
    <td style="white-space: nowrap; text-align: right">3.69 K</td>
    <td style="white-space: nowrap; text-align: right">271.14 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;23.59%</td>
    <td style="white-space: nowrap; text-align: right">265.67 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">444.17 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http1</td>
    <td style="white-space: nowrap; text-align: right">2.79 K</td>
    <td style="white-space: nowrap; text-align: right">358.75 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;31.64%</td>
    <td style="white-space: nowrap; text-align: right">342.67 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">713.92 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">2.44 K</td>
    <td style="white-space: nowrap; text-align: right">409.01 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;18.88%</td>
    <td style="white-space: nowrap; text-align: right">403.25 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">615.14 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap; text-align: right">1.84 K</td>
    <td style="white-space: nowrap; text-align: right">542.44 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;29.39%</td>
    <td style="white-space: nowrap; text-align: right">513.59 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">1038.89 &micro;s</td>
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
    <td style="white-space: nowrap;text-align: right">3.69 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http1</td>
    <td style="white-space: nowrap; text-align: right">2.79 K</td>
    <td style="white-space: nowrap; text-align: right">1.32x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">2.44 K</td>
    <td style="white-space: nowrap; text-align: right">1.51x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap; text-align: right">1.84 K</td>
    <td style="white-space: nowrap; text-align: right">2.0x</td>
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
    <td style="white-space: nowrap">7.98 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">finch http1</td>
    <td style="white-space: nowrap">12.83 KB</td>
    <td>1.61x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">0.76 KB</td>
    <td>0.1x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap">5.13 KB</td>
    <td>0.64x</td>
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
    <td style="white-space: nowrap">817.34</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">finch http1</td>
    <td style="white-space: nowrap">1024.02</td>
    <td>1.25x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">25.00</td>
    <td>0.03x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap">322.85</td>
    <td>0.4x</td>
  </tr>
</table>