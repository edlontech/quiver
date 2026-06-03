Benchmark

Benchmark run from 2026-06-03 12:14:29.776171Z UTC

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
    <td style="white-space: nowrap; text-align: right">267.12 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;23.37%</td>
    <td style="white-space: nowrap; text-align: right">261.71 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">431.13 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http1</td>
    <td style="white-space: nowrap; text-align: right">2.85 K</td>
    <td style="white-space: nowrap; text-align: right">351.06 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;27.02%</td>
    <td style="white-space: nowrap; text-align: right">340.71 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">621.88 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">2.49 K</td>
    <td style="white-space: nowrap; text-align: right">402.34 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;19.13%</td>
    <td style="white-space: nowrap; text-align: right">396.71 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">605.46 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap; text-align: right">2.28 K</td>
    <td style="white-space: nowrap; text-align: right">438.84 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;28.17%</td>
    <td style="white-space: nowrap; text-align: right">418.25 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">815.13 &micro;s</td>
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
    <td style="white-space: nowrap">finch http1</td>
    <td style="white-space: nowrap; text-align: right">2.85 K</td>
    <td style="white-space: nowrap; text-align: right">1.31x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap; text-align: right">2.49 K</td>
    <td style="white-space: nowrap; text-align: right">1.51x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap; text-align: right">2.28 K</td>
    <td style="white-space: nowrap; text-align: right">1.64x</td>
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
    <td style="white-space: nowrap">finch http1</td>
    <td style="white-space: nowrap">13.06 KB</td>
    <td>1.66x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">0.77 KB</td>
    <td>0.1x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap">5.24 KB</td>
    <td>0.67x</td>
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
    <td style="white-space: nowrap">827.25</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">finch http1</td>
    <td style="white-space: nowrap">1113.43</td>
    <td>1.35x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">quiver http2</td>
    <td style="white-space: nowrap">25.00</td>
    <td>0.03x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">finch http2</td>
    <td style="white-space: nowrap">368.85</td>
    <td>0.45x</td>
  </tr>
</table>