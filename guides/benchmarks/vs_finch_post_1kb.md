Benchmark

Benchmark run from 2026-03-06 20:39:08.339752Z UTC

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
    <td style="white-space: nowrap; text-align: right">3.72 K</td>
    <td style="white-space: nowrap; text-align: right">268.92 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;22.58%</td>
    <td style="white-space: nowrap; text-align: right">264.08 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">433.63 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http1</td>
    <td style="white-space: nowrap; text-align: right">2.93 K</td>
    <td style="white-space: nowrap; text-align: right">341.11 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;26.88%</td>
    <td style="white-space: nowrap; text-align: right">331.33 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">600.09 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">2.44 K</td>
    <td style="white-space: nowrap; text-align: right">409.21 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;19.37%</td>
    <td style="white-space: nowrap; text-align: right">402.88 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">623.71 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap; text-align: right">1.35 K</td>
    <td style="white-space: nowrap; text-align: right">742.81 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;41.15%</td>
    <td style="white-space: nowrap; text-align: right">663.54 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">1760.49 &micro;s</td>
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
    <td style="white-space: nowrap;text-align: right">3.72 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http1</td>
    <td style="white-space: nowrap; text-align: right">2.93 K</td>
    <td style="white-space: nowrap; text-align: right">1.27x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">2.44 K</td>
    <td style="white-space: nowrap; text-align: right">1.52x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap; text-align: right">1.35 K</td>
    <td style="white-space: nowrap; text-align: right">2.76x</td>
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
    <td style="white-space: nowrap">0.76 KB</td>
    <td>0.09x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap">5.08 KB</td>
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
    <td style="white-space: nowrap">866.11</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">finch http1</td>
    <td style="white-space: nowrap">1175.43</td>
    <td>1.36x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">25.00</td>
    <td>0.03x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap">321.32</td>
    <td>0.37x</td>
  </tr>
</table>