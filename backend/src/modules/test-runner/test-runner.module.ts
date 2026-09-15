import { Module } from '@nestjs/common';
import { TestRunnerController } from './test-runner.controller';

@Module({
  controllers: [TestRunnerController],
})
export class TestRunnerModule {}
