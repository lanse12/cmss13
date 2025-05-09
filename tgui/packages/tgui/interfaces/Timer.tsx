import { useBackend } from 'tgui/backend';
import { Button, Section, Slider } from 'tgui/components';
import { Window } from 'tgui/layouts';

type Data = {
  current_time: number;
  is_timing: number;
  min_time: number;
  max_time: number;
};

export const Timer = (props) => {
  const { act, data } = useBackend<Data>();
  const { max_time, min_time } = data;

  const window_width = 360;
  return (
    <Window width={window_width} height={120}>
      <Window.Content>
        <Section>
          <Button
            fluid
            color={data.is_timing ? 'green' : 'red'}
            icon="clock"
            onClick={() => act('set_timing', { should_time: !data.is_timing })}
          >
            {data.is_timing ? 'Enabled' : 'Disabled'}
          </Button>
        </Section>
        <Section>
          <Slider
            maxValue={max_time}
            minValue={min_time}
            value={data.current_time}
            onChange={(e, value) => act('set_time', { time: value })}
            unit="Seconds"
            stepPixelSize={window_width / max_time} // width / max_time
          />
        </Section>
      </Window.Content>
    </Window>
  );
};
