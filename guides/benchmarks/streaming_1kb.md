Benchmark

Benchmark run from 2026-03-04 10:47:42.189497Z UTC

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
    <td style="white-space: nowrap; text-align: right">7.06 K</td>
    <td style="white-space: nowrap; text-align: right">141.69 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;20.84%</td>
    <td style="white-space: nowrap; text-align: right">138.13 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">236.50 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 stream</td>
    <td style="white-space: nowrap; text-align: right">6.05 K</td>
    <td style="white-space: nowrap; text-align: right">165.28 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;24.48%</td>
    <td style="white-space: nowrap; text-align: right">159.75 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">291.50 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 collected</td>
    <td style="white-space: nowrap; text-align: right">2.66 K</td>
    <td style="white-space: nowrap; text-align: right">376.50 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;22.25%</td>
    <td style="white-space: nowrap; text-align: right">358.08 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">670.50 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 stream</td>
    <td style="white-space: nowrap; text-align: right">2.51 K</td>
    <td style="white-space: nowrap; text-align: right">398.84 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;19.69%</td>
    <td style="white-space: nowrap; text-align: right">385.17 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">609.71 &micro;s</td>
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
    <td style="white-space: nowrap;text-align: right">7.06 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 stream</td>
    <td style="white-space: nowrap; text-align: right">6.05 K</td>
    <td style="white-space: nowrap; text-align: right">1.17x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 collected</td>
    <td style="white-space: nowrap; text-align: right">2.66 K</td>
    <td style="white-space: nowrap; text-align: right">2.66x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 stream</td>
    <td style="white-space: nowrap; text-align: right">2.51 K</td>
    <td style="white-space: nowrap; text-align: right">2.81x</td>
  </tr>

</table>