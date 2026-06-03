Benchmark

Benchmark run from 2026-06-03 12:10:12.390867Z UTC

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
    <td style="white-space: nowrap">10</td>
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
    <td style="white-space: nowrap">http1 collected</td>
    <td style="white-space: nowrap; text-align: right">7.35 K</td>
    <td style="white-space: nowrap; text-align: right">136.10 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;21.08%</td>
    <td style="white-space: nowrap; text-align: right">133.71 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">206.58 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 stream</td>
    <td style="white-space: nowrap; text-align: right">6.52 K</td>
    <td style="white-space: nowrap; text-align: right">153.28 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;18.11%</td>
    <td style="white-space: nowrap; text-align: right">151 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">229.42 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 collected</td>
    <td style="white-space: nowrap; text-align: right">3.49 K</td>
    <td style="white-space: nowrap; text-align: right">286.78 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;20.35%</td>
    <td style="white-space: nowrap; text-align: right">281.21 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">447.54 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 stream</td>
    <td style="white-space: nowrap; text-align: right">3.25 K</td>
    <td style="white-space: nowrap; text-align: right">307.93 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;19.17%</td>
    <td style="white-space: nowrap; text-align: right">302.58 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">469.21 &micro;s</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">http1 collected</td>
    <td style="white-space: nowrap;text-align: right">7.35 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 stream</td>
    <td style="white-space: nowrap; text-align: right">6.52 K</td>
    <td style="white-space: nowrap; text-align: right">1.13x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 collected</td>
    <td style="white-space: nowrap; text-align: right">3.49 K</td>
    <td style="white-space: nowrap; text-align: right">2.11x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 stream</td>
    <td style="white-space: nowrap; text-align: right">3.25 K</td>
    <td style="white-space: nowrap; text-align: right">2.26x</td>
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
    <td style="white-space: nowrap">http1 collected</td>
    <td style="white-space: nowrap">7.88 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 stream</td>
    <td style="white-space: nowrap">2.15 KB</td>
    <td>0.27x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 collected</td>
    <td style="white-space: nowrap">0.77 KB</td>
    <td>0.1x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 stream</td>
    <td style="white-space: nowrap">1.29 KB</td>
    <td>0.16x</td>
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
    <td style="white-space: nowrap">http1 collected</td>
    <td style="white-space: nowrap">828.72</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 stream</td>
    <td style="white-space: nowrap">114.00</td>
    <td>0.14x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 collected</td>
    <td style="white-space: nowrap">26.00</td>
    <td>0.03x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 stream</td>
    <td style="white-space: nowrap">73.77</td>
    <td>0.09x</td>
  </tr>
</table>